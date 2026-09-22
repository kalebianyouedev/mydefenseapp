import 'package:cloud_firestore/cloud_firestore.dart';

/// Organisation (structure/association) qu'un utilisateur crée pour
/// publier des événements et des posts en son nom. Stockée dans
/// Firestore, collection `organisations`.
class Organisation {
  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String? logoUrl;
  final DateTime? createdAt;

  const Organisation({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    this.logoUrl,
    this.createdAt,
  });

  factory Organisation.fromMap(String id, Map<String, dynamic> map) {
    final rawCreatedAt = map['createdAt'];
    return Organisation(
      id: id,
      ownerId: map['ownerId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      logoUrl: map['logoUrl'] as String?,
      createdAt: rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'name': name,
      'description': description,
      'logoUrl': logoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
