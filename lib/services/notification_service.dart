import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';

enum AppNotificationType { certification, withdrawal, moderation, info }

AppNotificationType _typeFromString(String? raw) => switch (raw) {
      'certification' => AppNotificationType.certification,
      'withdrawal' => AppNotificationType.withdrawal,
      'moderation' => AppNotificationType.moderation,
      _ => AppNotificationType.info,
    };

/// Notification envoyée par l'administrateur à un utilisateur
/// (certification accordée, retrait validé/payé/refusé, blocage...).
/// Stockée dans `users/{uid}/notifications`, lue en temps réel par l'app.
class AppNotification {
  final String id;
  final AppNotificationType type;
  final String title;
  final String body;
  final bool read;
  final DateTime? createdAt;

  /// true = bonne nouvelle (vert), false = mauvaise (rouge), null = neutre.
  final bool? positive;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.read = false,
    this.createdAt,
    this.positive,
  });

  factory AppNotification.fromMap(String id, Map<String, dynamic> map) {
    final at = map['createdAt'];
    return AppNotification(
      id: id,
      type: _typeFromString(map['type'] as String?),
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      read: map['read'] as bool? ?? false,
      createdAt: at is Timestamp ? at.toDate() : null,
      positive: map['positive'] as bool?,
    );
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _timeout = Duration(seconds: 15);

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('notifications');

  /// Envoi (utilisé par l'espace admin).
  Future<void> send({
    required String uid,
    required AppNotificationType type,
    required String title,
    required String body,
    bool? positive,
  }) {
    return _col(uid).add({
      'type': type.name,
      'title': title,
      'body': body,
      'positive': positive,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    }).timeout(_timeout);
  }

  /// Notifications de l'utilisateur courant, les plus récentes d'abord.
  Stream<List<AppNotification>> watchMine() {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return _col(uid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map((d) => AppNotification.fromMap(d.id, d.data())).toList())
        .handleError((_) => <AppNotification>[]);
  }

  Future<void> markAllRead(List<AppNotification> notifications) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    final unread = notifications.where((n) => !n.read).toList();
    if (unread.isEmpty) return;
    final batch = _db.batch();
    for (final n in unread) {
      batch.update(_col(uid).doc(n.id), {'read': true});
    }
    await batch.commit().timeout(_timeout);
  }

  Future<void> delete(String id) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    await _col(uid).doc(id).delete().timeout(_timeout);
  }
}
