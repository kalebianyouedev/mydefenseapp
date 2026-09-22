import 'package:cloud_firestore/cloud_firestore.dart';

/// Catégorie d'une campagne de vote (ex. "Meilleur artiste"), avec son
/// propre prix par vote. Stockée dans Firestore, sous-collection
/// `voteCampaigns/{campaignId}/categories`.
class VoteCategory {
  final String id;
  final String title;
  final String description;
  final num pricePerVote;
  final String? imageUrl;
  final DateTime? createdAt;

  const VoteCategory({
    required this.id,
    required this.title,
    this.description = '',
    required this.pricePerVote,
    this.imageUrl,
    this.createdAt,
  });

  factory VoteCategory.fromMap(String id, Map<String, dynamic> map) {
    final rawCreatedAt = map['createdAt'];
    return VoteCategory(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      pricePerVote: map['pricePerVote'] as num? ?? 0,
      imageUrl: map['imageUrl'] as String?,
      createdAt: rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'pricePerVote': pricePerVote,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
