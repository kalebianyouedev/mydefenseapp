import 'package:cloud_firestore/cloud_firestore.dart';

/// Candidat d'une catégorie de vote. Stocké dans Firestore,
/// sous-collection
/// `voteCampaigns/{campaignId}/categories/{categoryId}/candidates`.
class VoteCandidate {
  final String id;
  final int number;
  final String name;
  final String description;
  final String bio;
  final String? photoUrl;
  final int voteCount;
  final DateTime? createdAt;

  const VoteCandidate({
    required this.id,
    required this.number,
    required this.name,
    this.description = '',
    this.bio = '',
    this.photoUrl,
    this.voteCount = 0,
    this.createdAt,
  });

  factory VoteCandidate.fromMap(String id, Map<String, dynamic> map) {
    final rawCreatedAt = map['createdAt'];
    return VoteCandidate(
      id: id,
      number: (map['number'] as num?)?.toInt() ?? 0,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      bio: map['bio'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      voteCount: (map['voteCount'] as num?)?.toInt() ?? 0,
      createdAt: rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'number': number,
      'name': name,
      'description': description,
      'bio': bio,
      'photoUrl': photoUrl,
      'voteCount': voteCount,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
