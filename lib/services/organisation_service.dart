import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/organisation.dart';
import 'auth_service.dart';
import 'stockimg_client.dart';

/// Organisations créées par l'utilisateur, dans Firestore (collection
/// `organisations`) ; le logo éventuel est envoyé via StockImg.
class OrganisationService {
  OrganisationService._();
  static final OrganisationService instance = OrganisationService._();

  static const _timeout = Duration(seconds: 15);

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _organisations =>
      _db.collection('organisations');

  String? get _uid => AuthService.instance.currentUser?.uid;

  // ---------------------------------------------------------------------
  // Abonnements
  // ---------------------------------------------------------------------

  DocumentReference<Map<String, dynamic>> _followerDoc(String organisationId, String uid) =>
      _organisations.doc(organisationId).collection('followers').doc(uid);

  /// Miroir côté utilisateur, pour lister ses abonnements dans "Compte".
  CollectionReference<Map<String, dynamic>> _followedOrganisations(String uid) =>
      _db.collection('users').doc(uid).collection('followedOrganisations');

  Stream<bool> watchFollowing(String organisationId) {
    final uid = _uid;
    if (uid == null) return Stream.value(false);
    return _followerDoc(organisationId, uid)
        .snapshots()
        .map((s) => s.exists)
        .handleError((_) => false);
  }

  /// S'abonne à l'organisation, ou se désabonne si déjà abonné.
  Future<void> toggleFollow({
    required String organisationId,
    required String organisationName,
    String? organisationLogoUrl,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Utilisateur non connecté.');
    final followerRef = _followerDoc(organisationId, uid);
    final mirrorRef = _followedOrganisations(uid).doc(organisationId);
    final orgRef = _organisations.doc(organisationId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(followerRef);
      if (snap.exists) {
        tx.delete(followerRef);
        tx.delete(mirrorRef);
        tx.update(orgRef, {'followerCount': FieldValue.increment(-1)});
      } else {
        tx.set(followerRef, {'createdAt': FieldValue.serverTimestamp()});
        tx.set(mirrorRef, {
          'name': organisationName,
          'logoUrl': organisationLogoUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.update(orgRef, {'followerCount': FieldValue.increment(1)});
      }
    }).timeout(_timeout);
  }

  /// Organisations suivies par l'utilisateur courant (nom et logo tels
  /// qu'au moment de l'abonnement), les plus récentes d'abord.
  Stream<List<FollowedOrganisation>> watchFollowed() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _followedOrganisations(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FollowedOrganisation(
                  id: d.id,
                  name: d.data()['name'] as String? ?? '',
                  logoUrl: d.data()['logoUrl'] as String?,
                ))
            .toList())
        .handleError((_) => <FollowedOrganisation>[]);
  }

  Stream<Organisation?> watchOne(String organisationId) {
    return _organisations
        .doc(organisationId)
        .snapshots()
        .map((d) => d.exists ? Organisation.fromMap(d.id, d.data()!) : null)
        .handleError((_) => null);
  }

  /// L'organisateur demande la certification (nécessaire pour retirer
  /// ses gains). L'administrateur la valide ou non depuis l'espace admin.
  Future<void> requestCertification(String organisationId) {
    return _organisations.doc(organisationId).update({
      'certificationRequested': true,
      'certificationRequestedAt': FieldValue.serverTimestamp(),
    }).timeout(_timeout);
  }

  /// Organisations dont l'utilisateur courant est propriétaire.
  Stream<List<Organisation>> watchMine() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _organisations
        .where('ownerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Organisation.fromMap(d.id, d.data()))
            .toList())
        .handleError((_) => <Organisation>[]);
  }

  Future<Organisation> create({
    required String name,
    String? description,
    File? logoFile,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Utilisateur non connecté.');
    if (name.trim().isEmpty) {
      throw StateError('Le nom de l\'organisation est requis.');
    }

    String? logoUrl;
    if (logoFile != null) {
      logoUrl = await StockImgClient.instance.uploadFile(logoFile);
    }

    final doc = _organisations.doc();
    final organisation = Organisation(
      id: doc.id,
      ownerId: uid,
      name: name.trim(),
      description: (description?.trim().isEmpty ?? true)
          ? null
          : description!.trim(),
      logoUrl: logoUrl,
    );
    await doc.set(organisation.toMap()).timeout(_timeout);
    return organisation;
  }
}

/// Entrée de `users/{uid}/followedOrganisations`.
class FollowedOrganisation {
  final String id;
  final String name;
  final String? logoUrl;

  const FollowedOrganisation({required this.id, required this.name, this.logoUrl});
}
