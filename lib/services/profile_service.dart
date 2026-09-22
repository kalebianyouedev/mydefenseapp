import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

import '../models/user_profile.dart';
import 'stockimg_client.dart';

/// Lecture / écriture du profil utilisateur dans Firestore
/// (`users/{uid}`) et des images (photo / bannière) via StockImg.
class ProfileService {
  ProfileService._();
  static final ProfileService instance = ProfileService._();

  static const _timeout = Duration(seconds: 15);

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _docFor(String uid) =>
      _db.collection('users').doc(uid);

  /// Flux temps réel du profil (utile pour refléter les changements
  /// immédiatement dans l'UI, ex. avatar dans "Mon compte"). En cas
  /// d'erreur (règles, réseau...), émet `null` plutôt que de bloquer.
  Stream<UserProfile?> watchProfile(String uid) {
    return _docFor(uid).snapshots().map(
          (snap) => snap.exists ? UserProfile.fromMap(snap.data()!) : null,
        ).handleError((_) => null);
  }

  Future<UserProfile?> fetchProfile(String uid) async {
    final snap = await _docFor(uid).get().timeout(_timeout);
    if (!snap.exists) return null;
    return UserProfile.fromMap(snap.data()!);
  }

  Future<void> saveProfile(String uid, UserProfile profile) async {
    await _docFor(uid)
        .set(profile.toMap(), SetOptions(merge: true))
        .timeout(_timeout);
  }

  /// Upload une image (photo de profil ou bannière) via StockImg et
  /// renvoie son URL publique.
  Future<String> uploadImage({
    required String uid,
    required File file,
    required bool isBanner,
  }) {
    return StockImgClient.instance.uploadFile(file);
  }
}

/// Construit un [ImageProvider] à partir d'une URL (StockImg ou autre) ou
/// d'un chemin de fichier local (aperçu avant sauvegarde), selon le format.
ImageProvider? imageProviderFromPath(String? pathOrUrl) {
  if (pathOrUrl == null || pathOrUrl.isEmpty) return null;
  if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
    return NetworkImage(pathOrUrl);
  }
  final file = File(pathOrUrl);
  return file.existsSync() ? FileImage(file) : null;
}
