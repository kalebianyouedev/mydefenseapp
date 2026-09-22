import 'package:cloud_firestore/cloud_firestore.dart';

/// Code promo appliqué au checkout d'un événement (réduction en %).
/// Stocké dans Firestore, sous-collection `events/{eventId}/promoCodes`,
/// avec le code lui-même (majuscules) comme id de document.
class PromoCode {
  final String code;
  final int percentOff;
  final int? maxUses;
  final int usedCount;
  final DateTime? createdAt;

  const PromoCode({
    required this.code,
    required this.percentOff,
    this.maxUses,
    this.usedCount = 0,
    this.createdAt,
  });

  bool get isExhausted => maxUses != null && usedCount >= maxUses!;

  factory PromoCode.fromMap(String code, Map<String, dynamic> map) {
    final rawCreatedAt = map['createdAt'];
    return PromoCode(
      code: code,
      percentOff: (map['percentOff'] as num?)?.toInt() ?? 0,
      maxUses: (map['maxUses'] as num?)?.toInt(),
      usedCount: (map['usedCount'] as num?)?.toInt() ?? 0,
      createdAt: rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'percentOff': percentOff,
      'maxUses': maxUses,
      'usedCount': usedCount,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
