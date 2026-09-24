import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/organisation.dart';
import '../models/payment_method.dart';
import '../models/vote_campaign.dart';
import '../models/vote_candidate.dart';
import '../models/vote_category.dart';
import '../models/vote_order.dart';
import 'auth_service.dart';
import 'profile_service.dart';
import 'stockimg_client.dart';

/// Campagnes de vote payant (collection `voteCampaigns`), leurs
/// catégories et candidats (sous-collections), et les achats de votes
/// (collection `voteOrders`). Même logique de paiement simulé que les
/// commandes de billets : une commande est créée "en attente" puis
/// confirmée manuellement par l'acheteur (aucune passerelle Mobile Money
/// réelle n'est branchée).
class VoteService {
  VoteService._();
  static final VoteService instance = VoteService._();

  static const _timeout = Duration(seconds: 15);

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _campaigns =>
      _db.collection('voteCampaigns');
  CollectionReference<Map<String, dynamic>> get _voteOrders =>
      _db.collection('voteOrders');

  CollectionReference<Map<String, dynamic>> _categories(String campaignId) =>
      _campaigns.doc(campaignId).collection('categories');
  CollectionReference<Map<String, dynamic>> _candidates(
          String campaignId, String categoryId) =>
      _categories(campaignId).doc(categoryId).collection('candidates');

  String? get _uid => AuthService.instance.currentUser?.uid;

  // ---------------------------------------------------------------------
  // Campagnes
  // ---------------------------------------------------------------------

  Future<String> createCampaign({
    required Organisation organisation,
    required String title,
    required String description,
    required File coverImageFile,
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Utilisateur non connecté.');
    if (title.trim().isEmpty) {
      throw StateError('Le titre de la campagne est requis.');
    }
    if (organisation.blocked) {
      throw StateError("Cette organisation est bloquée par l'administrateur.");
    }

    final coverImageUrl = await StockImgClient.instance.uploadFile(coverImageFile);

    final doc = _campaigns.doc();
    final campaign = VoteCampaign(
      id: doc.id,
      organisationId: organisation.id,
      organisationName: organisation.name,
      organisationCertified: organisation.certified,
      ownerId: uid,
      title: title.trim(),
      description: description.trim(),
      coverImageUrl: coverImageUrl,
      startsAt: startsAt,
      endsAt: endsAt,
    );
    await doc.set(campaign.toMap()).timeout(_timeout);
    return doc.id;
  }

  Future<void> setStatus(String campaignId, VoteCampaignStatus status) {
    return _campaigns.doc(campaignId).update({
      'status': switch (status) {
        VoteCampaignStatus.active => 'active',
        VoteCampaignStatus.ended => 'ended',
        VoteCampaignStatus.cancelled => 'cancelled',
        VoteCampaignStatus.draft => 'draft',
      },
    }).timeout(_timeout);
  }

  Future<void> deleteCampaign(String campaignId) {
    return _campaigns.doc(campaignId).delete().timeout(_timeout);
  }

  Stream<List<VoteCampaign>> watchByOrganisation(String organisationId) {
    return _campaigns
        .where('organisationId', isEqualTo: organisationId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => VoteCampaign.fromMap(d.id, d.data())).toList())
        .handleError((_) => <VoteCampaign>[]);
  }

  /// Toutes les campagnes créées par l'utilisateur courant, toutes ses
  /// organisations confondues. Utilisé par "Mes publications".
  Stream<List<VoteCampaign>> watchMine() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _campaigns
        .where('ownerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => VoteCampaign.fromMap(d.id, d.data())).toList())
        .handleError((_) => <VoteCampaign>[]);
  }

  /// Campagnes actives, toutes organisations confondues : fil public de
  /// vote.
  Stream<List<VoteCampaign>> watchActive() {
    return _campaigns
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) =>
            snap.docs
            .map((d) => VoteCampaign.fromMap(d.id, d.data()))
            .where((c) => !c.hiddenByAdmin)
            .toList())
        .handleError((_) => <VoteCampaign>[]);
  }

  /// Version ponctuelle de [watchActive], pour l'assistant IA.
  Future<List<VoteCampaign>> fetchActive({int limit = 20}) async {
    final snap = await _campaigns
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get()
        .timeout(_timeout);
    return snap.docs
        .map((d) => VoteCampaign.fromMap(d.id, d.data()))
        .where((c) => !c.hiddenByAdmin)
        .toList();
  }

  Future<List<VoteCategory>> fetchCategories(String campaignId) async {
    final snap = await _categories(campaignId)
        .orderBy('createdAt', descending: false)
        .get()
        .timeout(_timeout);
    return snap.docs.map((d) => VoteCategory.fromMap(d.id, d.data())).toList();
  }

  /// Candidats les plus votés d'une catégorie (classement).
  Future<List<VoteCandidate>> fetchTopCandidates(
      String campaignId, String categoryId,
      {int limit = 10}) async {
    final snap = await _candidates(campaignId, categoryId)
        .orderBy('voteCount', descending: true)
        .limit(limit)
        .get()
        .timeout(_timeout);
    return snap.docs
        .map((d) => VoteCandidate.fromMap(d.id, d.data()))
        .toList();
  }

  Stream<VoteCampaign?> watchOne(String campaignId) {
    return _campaigns
        .doc(campaignId)
        .snapshots()
        .map((d) => d.exists ? VoteCampaign.fromMap(d.id, d.data()!) : null)
        .handleError((_) => null);
  }

  // ---------------------------------------------------------------------
  // Catégories
  // ---------------------------------------------------------------------

  Future<void> addCategory({
    required String campaignId,
    required String title,
    required String description,
    required num pricePerVote,
    File? imageFile,
  }) async {
    if (title.trim().isEmpty) {
      throw StateError('Le titre de la catégorie est requis.');
    }
    if (pricePerVote <= 0) {
      throw StateError('Le prix par vote doit être supérieur à 0.');
    }
    String? imageUrl;
    if (imageFile != null) {
      imageUrl = await StockImgClient.instance.uploadFile(imageFile);
    }
    final doc = _categories(campaignId).doc();
    final category = VoteCategory(
      id: doc.id,
      title: title.trim(),
      description: description.trim(),
      pricePerVote: pricePerVote,
      imageUrl: imageUrl,
    );
    await doc.set(category.toMap()).timeout(_timeout);
  }

  Future<void> deleteCategory(String campaignId, String categoryId) {
    return _categories(campaignId).doc(categoryId).delete().timeout(_timeout);
  }

  Stream<List<VoteCategory>> watchCategories(String campaignId) {
    return _categories(campaignId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => VoteCategory.fromMap(d.id, d.data())).toList())
        .handleError((_) => <VoteCategory>[]);
  }

  // ---------------------------------------------------------------------
  // Candidats
  // ---------------------------------------------------------------------

  Future<void> addCandidate({
    required String campaignId,
    required String categoryId,
    required String name,
    required String description,
    required String bio,
    required File photoFile,
  }) async {
    if (name.trim().isEmpty) {
      throw StateError('Le nom du candidat est requis.');
    }
    final photoUrl = await StockImgClient.instance.uploadFile(photoFile);
    final existing = await _candidates(campaignId, categoryId).count().get().timeout(_timeout);
    final number = (existing.count ?? 0) + 1;
    final doc = _candidates(campaignId, categoryId).doc();
    final candidate = VoteCandidate(
      id: doc.id,
      number: number,
      name: name.trim(),
      description: description.trim(),
      bio: bio.trim(),
      photoUrl: photoUrl,
    );
    await doc.set(candidate.toMap()).timeout(_timeout);
  }

  Future<void> deleteCandidate(
      String campaignId, String categoryId, String candidateId) {
    return _candidates(campaignId, categoryId)
        .doc(candidateId)
        .delete()
        .timeout(_timeout);
  }

  Stream<List<VoteCandidate>> watchCandidates(
      String campaignId, String categoryId) {
    return _candidates(campaignId, categoryId)
        .orderBy('voteCount', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => VoteCandidate.fromMap(d.id, d.data())).toList())
        .handleError((_) => <VoteCandidate>[]);
  }

  // ---------------------------------------------------------------------
  // Achat de votes
  // ---------------------------------------------------------------------

  Future<String> createVoteOrder({
    required VoteCampaign campaign,
    required VoteCategory category,
    required VoteCandidate candidate,
    required int quantity,
    required PaymentMethod paymentMethod,
    required String paymentPhone,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Utilisateur non connecté.');
    if (quantity <= 0) throw StateError('Choisissez au moins un vote.');

    final profile = await ProfileService.instance.fetchProfile(uid);
    final user = AuthService.instance.currentUser;
    final buyerName = profile?.fullName.isNotEmpty == true
        ? profile!.fullName
        : (user?.displayName?.isNotEmpty == true
            ? user!.displayName!
            : (user?.email ?? 'Client'));

    final doc = _voteOrders.doc();
    final order = VoteOrder(
      id: doc.id,
      campaignId: campaign.id,
      campaignTitle: campaign.title,
      organisationId: campaign.organisationId,
      organisationName: campaign.organisationName,
      ownerId: campaign.ownerId,
      categoryId: category.id,
      categoryTitle: category.title,
      candidateId: candidate.id,
      candidateName: candidate.name,
      quantity: quantity,
      unitPrice: category.pricePerVote,
      totalAmount: category.pricePerVote * quantity,
      buyerId: uid,
      buyerName: buyerName,
      paymentMethod: paymentMethod,
      paymentPhone: paymentPhone.trim(),
    );
    await doc.set(order.toMap()).timeout(_timeout);
    return doc.id;
  }

  /// Simule la confirmation du paiement : incrémente le compteur de
  /// votes du candidat puis marque la commande "confirmed".
  Future<void> confirmVoteOrder(String orderId) async {
    final orderRef = _voteOrders.doc(orderId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(orderRef);
      if (!snap.exists) throw StateError('Commande introuvable.');
      final order = VoteOrder.fromMap(snap.id, snap.data()!);
      if (order.status == VoteOrderStatus.confirmed) return;

      final candidateRef =
          _candidates(order.campaignId, order.categoryId).doc(order.candidateId);
      tx.update(candidateRef, {'voteCount': FieldValue.increment(order.quantity)});
      tx.update(orderRef, {
        'status': 'confirmed',
        'confirmedAt': FieldValue.serverTimestamp(),
      });
    }).timeout(const Duration(seconds: 20));
  }

  Stream<VoteOrder?> watchOrder(String orderId) {
    return _voteOrders
        .doc(orderId)
        .snapshots()
        .map((d) => d.exists ? VoteOrder.fromMap(d.id, d.data()!) : null)
        .handleError((_) => null);
  }

  /// Commandes de votes d'une campagne, pour sa vue financière.
  Stream<List<VoteOrder>> watchCampaignOrders(String campaignId) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _voteOrders
        .where('ownerId', isEqualTo: uid)
        .where('campaignId', isEqualTo: campaignId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => VoteOrder.fromMap(d.id, d.data())).toList())
        .handleError((_) => <VoteOrder>[]);
  }
}
