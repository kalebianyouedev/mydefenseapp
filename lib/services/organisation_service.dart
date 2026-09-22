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
