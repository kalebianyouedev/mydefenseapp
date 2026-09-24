import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/event.dart';
import '../models/event_category.dart';
import '../models/organisation.dart';
import '../models/payment_method.dart';
import '../models/promo_code.dart';
import '../models/ticket_type.dart';
import 'auth_service.dart';
import 'stockimg_client.dart';

/// Événements (collection `events`), leurs types de billets
/// (sous-collection `ticketTypes`) et leurs codes promo (sous-collection
/// `promoCodes`).
class EventService {
  EventService._();
  static final EventService instance = EventService._();

  static const _timeout = Duration(seconds: 15);

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _events =>
      _db.collection('events');

  String? get _uid => AuthService.instance.currentUser?.uid;

  // ---------------------------------------------------------------------
  // Lecture
  // ---------------------------------------------------------------------

  /// Fil public : les événements publiés, les plus récents d'abord.
  /// Utilisé par la page d'accueil.
  Stream<List<Event>> watchPublished() {
    return _events
        .where('status', isEqualTo: 'published')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Event.fromMap(d.id, d.data()))
            .where((e) => !e.hiddenByAdmin)
            .toList())
        .handleError((_) => <Event>[]);
  }

  /// Tous les événements (brouillon, publié, annulé) d'une organisation,
  /// pour son tableau de bord.
  Stream<List<Event>> watchByOrganisation(String organisationId) {
    return _events
        .where('organisationId', isEqualTo: organisationId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Event.fromMap(d.id, d.data())).toList())
        .handleError((_) => <Event>[]);
  }

  /// Tous les événements créés par l'utilisateur courant, toutes ses
  /// organisations confondues. Utilisé par "Mes publications".
  Stream<List<Event>> watchMine() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _events
        .where('ownerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Event.fromMap(d.id, d.data())).toList())
        .handleError((_) => <Event>[]);
  }

  Stream<Event?> watchOne(String eventId) {
    return _events
        .doc(eventId)
        .snapshots()
        .map((d) => d.exists ? Event.fromMap(d.id, d.data()!) : null)
        .handleError((_) => null);
  }

  /// Version ponctuelle de [watchPublished], pour l'assistant IA.
  Future<List<Event>> fetchPublished() async {
    final snap = await _events
        .where('status', isEqualTo: 'published')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get()
        .timeout(_timeout);
    return snap.docs
        .map((d) => Event.fromMap(d.id, d.data()))
        .where((e) => !e.hiddenByAdmin)
        .toList();
  }

  Future<Event?> fetchOne(String eventId) async {
    final snap = await _events.doc(eventId).get().timeout(_timeout);
    if (!snap.exists) return null;
    return Event.fromMap(snap.id, snap.data()!);
  }

  Future<void> incrementViews(String eventId) {
    return _events
        .doc(eventId)
        .update({'views': FieldValue.increment(1)}).timeout(_timeout);
  }

  // ---------------------------------------------------------------------
  // J'aime (favoris)
  // ---------------------------------------------------------------------

  DocumentReference<Map<String, dynamic>> _likeDoc(String eventId, String uid) =>
      _events.doc(eventId).collection('likes').doc(uid);

  /// Miroir côté utilisateur, pour lister ses favoris dans "Compte".
  DocumentReference<Map<String, dynamic>> _likedEventDoc(String uid, String eventId) =>
      _db.collection('users').doc(uid).collection('likedEvents').doc(eventId);

  Stream<bool> watchLiked(String eventId) {
    final uid = _uid;
    if (uid == null) return Stream.value(false);
    return _likeDoc(eventId, uid)
        .snapshots()
        .map((s) => s.exists)
        .handleError((_) => false);
  }

  Future<void> toggleLike(Event event) async {
    final uid = _uid;
    if (uid == null) throw StateError('Utilisateur non connecté.');
    final likeRef = _likeDoc(event.id, uid);
    final mirrorRef = _likedEventDoc(uid, event.id);
    final eventRef = _events.doc(event.id);

    await _db.runTransaction((tx) async {
      final likeSnap = await tx.get(likeRef);
      if (likeSnap.exists) {
        tx.delete(likeRef);
        tx.delete(mirrorRef);
        tx.update(eventRef, {'likeCount': FieldValue.increment(-1)});
      } else {
        tx.set(likeRef, {'createdAt': FieldValue.serverTimestamp()});
        tx.set(mirrorRef, {'createdAt': FieldValue.serverTimestamp()});
        tx.update(eventRef, {'likeCount': FieldValue.increment(1)});
      }
    }).timeout(_timeout);
  }

  /// Ids des événements aimés par l'utilisateur, du plus récent au plus
  /// ancien.
  Stream<List<String>> watchLikedEventIds() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _db
        .collection('users')
        .doc(uid)
        .collection('likedEvents')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toList())
        .handleError((_) => <String>[]);
  }

  // ---------------------------------------------------------------------
  // Boost
  // ---------------------------------------------------------------------

  static const minBoostAmount = 100;

  /// Booste un événement : l'utilisateur envoie [amount] F CFA (100 F
  /// minimum) par Orange Money / MTN Mobile Money. Aucune passerelle
  /// réelle n'est branchée : le paiement est simulé comme pour les
  /// billets et les votes. Le boost est tracé dans `eventBoosts` et
  /// cumulé sur l'événement (`boosts`, `boostAmount`), ce qui le fait
  /// remonter dans le fil d'accueil.
  Future<void> boost({
    required Event event,
    required num amount,
    required PaymentMethod paymentMethod,
    required String paymentPhone,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Utilisateur non connecté.');
    if (amount < minBoostAmount) {
      throw StateError('Le boost minimum est de $minBoostAmount F CFA.');
    }
    if (paymentPhone.trim().length < 8) {
      throw StateError('Numéro de paiement invalide.');
    }
    final batch = _db.batch();
    batch.set(_db.collection('eventBoosts').doc(), {
      'eventId': event.id,
      'eventTitle': event.title,
      'ownerId': event.ownerId,
      'buyerId': uid,
      'amount': amount,
      'currency': 'XAF',
      'paymentMethod': paymentMethodToString(paymentMethod),
      'paymentPhone': paymentPhone.trim(),
      'status': 'confirmed',
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_events.doc(event.id), {
      'boosts': FieldValue.increment(1),
      'boostAmount': FieldValue.increment(amount),
    });
    await batch.commit().timeout(_timeout);
  }

  // ---------------------------------------------------------------------
  // Création / édition
  // ---------------------------------------------------------------------

  /// Crée l'événement en brouillon et renvoie son id. Les images passent
  /// par StockImg (URL locale du fichier -> URL publique).
  Future<String> createDraft({
    required Organisation organisation,
    required String title,
    required String description,
    required String venue,
    required String city,
    required EventCategory category,
    File? coverImageFile,
    String? videoUrl,
    List<File> galleryFiles = const [],
    required List<Seance> seances,
    bool isFree = false,
    int? capacity,
    String? refundPolicy,
  }) async {
    final uid = _uid;
    if (organisation.blocked) {
      throw StateError("Cette organisation est bloquée par l'administrateur.");
    }
    if (uid == null) throw StateError('Utilisateur non connecté.');
    if (title.trim().isEmpty) {
      throw StateError('Le titre de l\'événement est requis.');
    }
    if (seances.isEmpty) {
      throw StateError('Ajoutez au moins une séance.');
    }

    String? coverImageUrl;
    if (coverImageFile != null) {
      coverImageUrl = await StockImgClient.instance.uploadFile(coverImageFile);
    }
    final gallery = <String>[];
    for (final file in galleryFiles) {
      gallery.add(await StockImgClient.instance.uploadFile(file));
    }

    final doc = _events.doc();
    final event = Event(
      id: doc.id,
      organisationId: organisation.id,
      organisationName: organisation.name,
      organisationCertified: organisation.certified,
      organisationLogoUrl: organisation.logoUrl,
      ownerId: uid,
      title: title.trim(),
      description: description.trim(),
      venue: venue.trim(),
      city: city.trim(),
      category: category,
      coverImageUrl: coverImageUrl,
      videoUrl: (videoUrl?.trim().isEmpty ?? true) ? null : videoUrl!.trim(),
      gallery: gallery,
      seances: seances,
      isFree: isFree,
      capacity: capacity,
      refundPolicy: (refundPolicy?.trim().isEmpty ?? true)
          ? null
          : refundPolicy!.trim(),
      status: EventStatus.draft,
    );
    await doc.set(event.toMap()).timeout(_timeout);
    return doc.id;
  }

  Future<void> updateDetails({
    required String eventId,
    required String title,
    required String description,
    required String venue,
    required String city,
    required EventCategory category,
    File? newCoverImageFile,
    String? coverImageUrl,
    String? videoUrl,
    required List<Seance> seances,
    bool isFree = false,
    int? capacity,
    String? refundPolicy,
  }) async {
    String? resolvedCoverUrl = coverImageUrl;
    if (newCoverImageFile != null) {
      resolvedCoverUrl =
          await StockImgClient.instance.uploadFile(newCoverImageFile);
    }
    await _events.doc(eventId).update({
      'title': title.trim(),
      'description': description.trim(),
      'venue': venue.trim(),
      'city': city.trim(),
      'category': category.id,
      'coverImageUrl': resolvedCoverUrl,
      'videoUrl': (videoUrl?.trim().isEmpty ?? true) ? null : videoUrl!.trim(),
      'seances': seances.map((s) => s.toMap()).toList(),
      'isFree': isFree,
      'capacity': capacity,
      'refundPolicy':
          (refundPolicy?.trim().isEmpty ?? true) ? null : refundPolicy!.trim(),
    }).timeout(_timeout);
  }

  /// Publie l'événement (il apparaît alors sur la page d'accueil).
  /// Nécessite au moins un type de billet configuré.
  Future<void> publish(String eventId) async {
    final types = await _ticketTypes(eventId).limit(1).get().timeout(_timeout);
    if (types.docs.isEmpty) {
      throw StateError(
          'Ajoutez au moins un type de billet avant de publier.');
    }
    await _events.doc(eventId).update({
      'status': 'published',
      'publishedAt': FieldValue.serverTimestamp(),
    }).timeout(_timeout);
  }

  Future<void> cancel(String eventId) {
    return _events.doc(eventId).update({'status': 'cancelled'}).timeout(_timeout);
  }

  Future<void> backToDraft(String eventId) {
    return _events.doc(eventId).update({'status': 'draft'}).timeout(_timeout);
  }

  Future<void> delete(String eventId) {
    return _events.doc(eventId).delete().timeout(_timeout);
  }

  // ---------------------------------------------------------------------
  // Types de billets
  // ---------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> _ticketTypes(String eventId) =>
      _events.doc(eventId).collection('ticketTypes');

  Stream<List<TicketType>> watchTicketTypes(String eventId) {
    return _ticketTypes(eventId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => TicketType.fromMap(d.id, d.data()))
            .toList())
        .handleError((_) => <TicketType>[]);
  }

  Future<List<TicketType>> fetchTicketTypes(String eventId) async {
    final snap = await _ticketTypes(eventId).get().timeout(_timeout);
    return snap.docs.map((d) => TicketType.fromMap(d.id, d.data())).toList();
  }

  /// Prix du billet le moins cher (null si aucun billet ou erreur).
  /// Utilisé par l'assistant IA pour filtrer selon le budget.
  Future<num?> fetchMinPrice(String eventId) async {
    try {
      final types = await fetchTicketTypes(eventId);
      if (types.isEmpty) return null;
      return types.map((t) => t.price).reduce((a, b) => a < b ? a : b);
    } catch (_) {
      return null;
    }
  }

  Future<void> addTicketType({
    required String eventId,
    required String seanceId,
    required String name,
    required num price,
    int? quantityTotal,
  }) async {
    if (name.trim().isEmpty) {
      throw StateError('Le nom du type de billet est requis.');
    }
    final doc = _ticketTypes(eventId).doc();
    final type = TicketType(
      id: doc.id,
      eventId: eventId,
      seanceId: seanceId,
      name: name.trim(),
      price: price,
      quantityTotal: quantityTotal,
    );
    await doc.set(type.toMap()).timeout(_timeout);
  }

  Future<void> updateTicketType({
    required String eventId,
    required String ticketTypeId,
    required String name,
    required num price,
    int? quantityTotal,
  }) async {
    await _ticketTypes(eventId).doc(ticketTypeId).update({
      'name': name.trim(),
      'price': price,
      'quantityTotal': quantityTotal,
    }).timeout(_timeout);
  }

  Future<void> deleteTicketType(String eventId, String ticketTypeId) {
    return _ticketTypes(eventId).doc(ticketTypeId).delete().timeout(_timeout);
  }

  // ---------------------------------------------------------------------
  // Codes promo
  // ---------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> _promoCodes(String eventId) =>
      _events.doc(eventId).collection('promoCodes');

  Stream<List<PromoCode>> watchPromoCodes(String eventId) {
    return _promoCodes(eventId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PromoCode.fromMap(d.id, d.data()))
            .toList())
        .handleError((_) => <PromoCode>[]);
  }

  Future<void> addPromoCode({
    required String eventId,
    required String code,
    required int percentOff,
    int? maxUses,
  }) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) throw StateError('Le code est requis.');
    final promo = PromoCode(code: normalized, percentOff: percentOff, maxUses: maxUses);
    await _promoCodes(eventId).doc(normalized).set(promo.toMap()).timeout(_timeout);
  }

  Future<void> deletePromoCode(String eventId, String code) {
    return _promoCodes(eventId).doc(code.toUpperCase()).delete().timeout(_timeout);
  }

  /// Renvoie le code promo s'il est valide (existe, pas épuisé), sinon
  /// `null`.
  Future<PromoCode?> validatePromoCode(String eventId, String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    final snap = await _promoCodes(eventId).doc(normalized).get().timeout(_timeout);
    if (!snap.exists) return null;
    final promo = PromoCode.fromMap(snap.id, snap.data()!);
    return promo.isExhausted ? null : promo;
  }
}
