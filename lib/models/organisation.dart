import 'package:cloud_firestore/cloud_firestore.dart';

/// Organisation (structure/association) qu'un utilisateur crée pour
/// publier des événements et des posts en son nom. Stockée dans
/// Firestore, collection `organisations`.
///
/// [certified] et [blocked] ne sont modifiables que par un
/// administrateur (voir firestore.rules) : seule une organisation
/// certifiée peut demander un retrait, et une organisation bloquée ne
/// peut plus rien publier (ses événements et votes sont masqués).
class Organisation {
  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String? logoUrl;
  final int followerCount;
  final DateTime? createdAt;

  final bool certified;
  final DateTime? certifiedAt;

  /// L'organisateur a demandé la certification (en attente d'examen).
  final bool certificationRequested;
  final DateTime? certificationRequestedAt;

  final bool blocked;
  final String? blockedReason;

  const Organisation({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    this.logoUrl,
    this.followerCount = 0,
    this.createdAt,
    this.certified = false,
    this.certifiedAt,
    this.certificationRequested = false,
    this.certificationRequestedAt,
    this.blocked = false,
    this.blockedReason,
  });

  static DateTime? _date(dynamic raw) => raw is Timestamp ? raw.toDate() : null;

  factory Organisation.fromMap(String id, Map<String, dynamic> map) {
    return Organisation(
      id: id,
      ownerId: map['ownerId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      logoUrl: map['logoUrl'] as String?,
      followerCount: (map['followerCount'] as num?)?.toInt() ?? 0,
      createdAt: _date(map['createdAt']),
      certified: map['certified'] as bool? ?? false,
      certifiedAt: _date(map['certifiedAt']),
      certificationRequested: map['certificationRequested'] as bool? ?? false,
      certificationRequestedAt: _date(map['certificationRequestedAt']),
      blocked: map['blocked'] as bool? ?? false,
      blockedReason: map['blockedReason'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'name': name,
      'description': description,
      'logoUrl': logoUrl,
      'followerCount': followerCount,
      'certified': false,
      'blocked': false,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
