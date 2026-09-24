import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';

/// Statut de modération d'un compte, écrit uniquement par un
/// administrateur (collection `userModeration`).
class AccountModeration {
  final bool blocked;
  final bool deleted;
  final String? reason;

  const AccountModeration({this.blocked = false, this.deleted = false, this.reason});

  static const none = AccountModeration();

  factory AccountModeration.fromMap(Map<String, dynamic>? map) {
    if (map == null) return none;
    return AccountModeration(
      blocked: map['blocked'] as bool? ?? false,
      deleted: map['deleted'] as bool? ?? false,
      reason: map['reason'] as String?,
    );
  }
}

/// Informations de compte partagées entre l'app et l'espace admin :
/// fiche `users/{uid}` (email, nom, dernière connexion), statut de
/// modération et rôle administrateur (`admins/{uid}`).
class AccountService {
  AccountService._();
  static final AccountService instance = AccountService._();

  static const _timeout = Duration(seconds: 15);

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Enregistre l'email, le nom et la date de dernière connexion sur la
  /// fiche utilisateur, pour que l'administrateur voie tous les comptes.
  Future<void> recordSignIn() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).set({
      'email': user.email,
      'displayName': user.displayName,
      'lastSeenAt': FieldValue.serverTimestamp(),
      if (user.metadata.creationTime != null)
        'accountCreatedAt': Timestamp.fromDate(user.metadata.creationTime!),
    }, SetOptions(merge: true)).timeout(_timeout);
  }

  Future<AccountModeration> fetchModeration(String uid) async {
    final snap = await _db.collection('userModeration').doc(uid).get().timeout(_timeout);
    return AccountModeration.fromMap(snap.data());
  }

  Future<bool> isAdmin(String uid) async {
    final snap = await _db.collection('admins').doc(uid).get().timeout(_timeout);
    return snap.exists;
  }
}
