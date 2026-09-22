import 'package:cloud_firestore/cloud_firestore.dart';

enum PostMediaType { image, video }

/// Publication du fil "Posts" (photo ou vidéo façon reels).
/// Stockée dans Firestore, collection `posts`.
class Post {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String mediaUrl;
  final PostMediaType mediaType;
  final String caption;
  final String? organisationId;
  final String? organisationName;
  final int likeCount;
  final int commentCount;
  final int saveCount;
  final int shareCount;
  final int repostCount;
  final int voteCount;
  final DateTime? createdAt;

  // Republication : renvoie vers la publication d'origine.
  final bool isRepost;
  final String? originalPostId;
  final String? originalAuthorName;

  const Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.mediaUrl,
    required this.mediaType,
    this.caption = '',
    this.organisationId,
    this.organisationName,
    this.likeCount = 0,
    this.commentCount = 0,
    this.saveCount = 0,
    this.shareCount = 0,
    this.repostCount = 0,
    this.voteCount = 0,
    this.createdAt,
    this.isRepost = false,
    this.originalPostId,
    this.originalAuthorName,
  });

  factory Post.fromMap(String id, Map<String, dynamic> map) {
    final rawCreatedAt = map['createdAt'];
    return Post(
      id: id,
      authorId: map['authorId'] as String? ?? '',
      authorName: map['authorName'] as String? ?? 'Utilisateur',
      authorPhotoUrl: map['authorPhotoUrl'] as String?,
      mediaUrl: map['mediaUrl'] as String? ?? '',
      mediaType: (map['mediaType'] as String?) == 'video'
          ? PostMediaType.video
          : PostMediaType.image,
      caption: map['caption'] as String? ?? '',
      organisationId: map['organisationId'] as String?,
      organisationName: map['organisationName'] as String?,
      likeCount: (map['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (map['commentCount'] as num?)?.toInt() ?? 0,
      saveCount: (map['saveCount'] as num?)?.toInt() ?? 0,
      shareCount: (map['shareCount'] as num?)?.toInt() ?? 0,
      repostCount: (map['repostCount'] as num?)?.toInt() ?? 0,
      voteCount: (map['voteCount'] as num?)?.toInt() ?? 0,
      createdAt:
          rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : null,
      isRepost: map['isRepost'] as bool? ?? false,
      originalPostId: map['originalPostId'] as String?,
      originalAuthorName: map['originalAuthorName'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType == PostMediaType.video ? 'video' : 'image',
      'caption': caption,
      'organisationId': organisationId,
      'organisationName': organisationName,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'saveCount': saveCount,
      'shareCount': shareCount,
      'repostCount': repostCount,
      'voteCount': voteCount,
      'createdAt': FieldValue.serverTimestamp(),
      'isRepost': isRepost,
      'originalPostId': originalPostId,
      'originalAuthorName': originalAuthorName,
    };
  }
}
