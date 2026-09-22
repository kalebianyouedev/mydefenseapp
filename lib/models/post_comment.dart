import 'package:cloud_firestore/cloud_firestore.dart';

/// Commentaire sur une publication. Stocké dans Firestore,
/// collection `posts/{postId}/comments`.
class PostComment {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String text;
  final DateTime? createdAt;

  const PostComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.text,
    this.createdAt,
  });

  factory PostComment.fromMap(String id, Map<String, dynamic> map) {
    final rawCreatedAt = map['createdAt'];
    return PostComment(
      id: id,
      authorId: map['authorId'] as String? ?? '',
      authorName: map['authorName'] as String? ?? 'Utilisateur',
      authorPhotoUrl: map['authorPhotoUrl'] as String?,
      text: map['text'] as String? ?? '',
      createdAt: rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
