import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/post.dart';
import '../models/post_comment.dart';
import 'auth_service.dart';
import 'profile_service.dart';
import 'stockimg_client.dart';

/// Fil "Posts" (photo/vidéo façon reels) : publications, likes,
/// sauvegardes, commentaires, abonnements et republications, le tout
/// dans Firestore. Les images passent par StockImg ; les vidéos, que
/// StockImg ne gère pas, restent sur Firebase Storage.
class PostService {
  PostService._();
  static final PostService instance = PostService._();

  static const _timeout = Duration(seconds: 15);

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection('posts');

  String? get _uid => AuthService.instance.currentUser?.uid;

  // ---------------------------------------------------------------------
  // Fil
  // ---------------------------------------------------------------------

  Stream<List<Post>> watchFeed() {
    return _posts
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Post.fromMap(d.id, d.data())).toList())
        .handleError((_) => <Post>[]);
  }

  // ---------------------------------------------------------------------
  // Création
  // ---------------------------------------------------------------------

  /// Upload le média puis crée la publication. Renvoie l'id créé.
  Future<String> createPost({
    required File mediaFile,
    required PostMediaType mediaType,
    required String caption,
    String? organisationId,
    String? organisationName,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Utilisateur non connecté.');

    final profile = await ProfileService.instance.fetchProfile(uid);
    final user = AuthService.instance.currentUser;
    final authorName = profile?.fullName.isNotEmpty == true
        ? profile!.fullName
        : (user?.displayName?.isNotEmpty == true
            ? user!.displayName!
            : (user?.email ?? 'Utilisateur'));

    final String mediaUrl;
    if (mediaType == PostMediaType.video) {
      final ref = _storage
          .ref()
          .child('posts')
          .child(uid)
          .child('${DateTime.now().millisecondsSinceEpoch}.mp4');
      await ref.putFile(mediaFile).timeout(const Duration(seconds: 90));
      mediaUrl = await ref.getDownloadURL().timeout(_timeout);
    } else {
      mediaUrl = await StockImgClient.instance.uploadFile(mediaFile);
    }

    final post = Post(
      id: '',
      authorId: uid,
      authorName: authorName,
      authorPhotoUrl: profile?.photoUrl,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      caption: caption.trim(),
      organisationId: organisationId,
      organisationName: organisationName,
    );

    final doc = await _posts.add(post.toMap()).timeout(_timeout);
    return doc.id;
  }

  /// Republie une publication existante sur le fil de l'utilisateur
  /// courant.
  Future<void> repost(Post original) async {
    final uid = _uid;
    if (uid == null) throw StateError('Utilisateur non connecté.');

    final profile = await ProfileService.instance.fetchProfile(uid);
    final user = AuthService.instance.currentUser;
    final authorName = profile?.fullName.isNotEmpty == true
        ? profile!.fullName
        : (user?.displayName?.isNotEmpty == true
            ? user!.displayName!
            : (user?.email ?? 'Utilisateur'));

    final repostDoc = Post(
      id: '',
      authorId: uid,
      authorName: authorName,
      authorPhotoUrl: profile?.photoUrl,
      mediaUrl: original.mediaUrl,
      mediaType: original.mediaType,
      caption: original.caption,
      isRepost: true,
      originalPostId: original.id,
      originalAuthorName: original.authorName,
    );

    final batch = _db.batch();
    batch.set(_posts.doc(), repostDoc.toMap());
    batch.update(_posts.doc(original.id), {
      'repostCount': FieldValue.increment(1),
    });
    await batch.commit().timeout(_timeout);
  }

  // ---------------------------------------------------------------------
  // Likes
  // ---------------------------------------------------------------------

  DocumentReference<Map<String, dynamic>> _likeDoc(String postId, String uid) =>
      _posts.doc(postId).collection('likes').doc(uid);

  Stream<bool> watchLiked(String postId) {
    final uid = _uid;
    if (uid == null) return Stream.value(false);
    return _likeDoc(postId, uid)
        .snapshots()
        .map((s) => s.exists)
        .handleError((_) => false);
  }

  Future<void> toggleLike(String postId) async {
    final uid = _uid;
    if (uid == null) throw StateError('Utilisateur non connecté.');
    final likeRef = _likeDoc(postId, uid);
    final postRef = _posts.doc(postId);

    await _db.runTransaction((tx) async {
      final likeSnap = await tx.get(likeRef);
      if (likeSnap.exists) {
        tx.delete(likeRef);
        tx.update(postRef, {'likeCount': FieldValue.increment(-1)});
      } else {
        tx.set(likeRef, {'createdAt': FieldValue.serverTimestamp()});
        tx.update(postRef, {'likeCount': FieldValue.increment(1)});
      }
    }).timeout(_timeout);
  }

  // ---------------------------------------------------------------------
  // Votes
  // ---------------------------------------------------------------------

  DocumentReference<Map<String, dynamic>> _voteDoc(String postId, String uid) =>
      _posts.doc(postId).collection('votes').doc(uid);

  Stream<bool> watchVoted(String postId) {
    final uid = _uid;
    if (uid == null) return Stream.value(false);
    return _voteDoc(postId, uid)
        .snapshots()
        .map((s) => s.exists)
        .handleError((_) => false);
  }

  Future<void> toggleVote(String postId) async {
    final uid = _uid;
    if (uid == null) throw StateError('Utilisateur non connecté.');
    final voteRef = _voteDoc(postId, uid);
    final postRef = _posts.doc(postId);

    await _db.runTransaction((tx) async {
      final voteSnap = await tx.get(voteRef);
      if (voteSnap.exists) {
        tx.delete(voteRef);
        tx.update(postRef, {'voteCount': FieldValue.increment(-1)});
      } else {
        tx.set(voteRef, {'createdAt': FieldValue.serverTimestamp()});
        tx.update(postRef, {'voteCount': FieldValue.increment(1)});
      }
    }).timeout(_timeout);
  }

  // ---------------------------------------------------------------------
  // Sauvegardes
  // ---------------------------------------------------------------------

  DocumentReference<Map<String, dynamic>> _saveDoc(String postId, String uid) =>
      _posts.doc(postId).collection('saves').doc(uid);

  DocumentReference<Map<String, dynamic>> _userSaveDoc(
          String uid, String postId) =>
      _db.collection('users').doc(uid).collection('saves').doc(postId);

  Stream<bool> watchSaved(String postId) {
    final uid = _uid;
    if (uid == null) return Stream.value(false);
    return _saveDoc(postId, uid)
        .snapshots()
        .map((s) => s.exists)
        .handleError((_) => false);
  }

  Future<void> toggleSave(String postId) async {
    final uid = _uid;
    if (uid == null) throw StateError('Utilisateur non connecté.');
    final saveRef = _saveDoc(postId, uid);
    final userSaveRef = _userSaveDoc(uid, postId);
    final postRef = _posts.doc(postId);

    await _db.runTransaction((tx) async {
      final saveSnap = await tx.get(saveRef);
      if (saveSnap.exists) {
        tx.delete(saveRef);
        tx.delete(userSaveRef);
        tx.update(postRef, {'saveCount': FieldValue.increment(-1)});
      } else {
        final now = FieldValue.serverTimestamp();
        tx.set(saveRef, {'createdAt': now});
        tx.set(userSaveRef, {'createdAt': now});
        tx.update(postRef, {'saveCount': FieldValue.increment(1)});
      }
    }).timeout(_timeout);
  }

  // ---------------------------------------------------------------------
  // Partage
  // ---------------------------------------------------------------------

  Future<void> registerShare(String postId) async {
    await _posts
        .doc(postId)
        .update({'shareCount': FieldValue.increment(1)}).timeout(_timeout);
  }

  // ---------------------------------------------------------------------
  // Commentaires
  // ---------------------------------------------------------------------

  Stream<List<PostComment>> watchComments(String postId) {
    return _posts
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PostComment.fromMap(d.id, d.data()))
            .toList())
        .handleError((_) => <PostComment>[]);
  }

  Future<void> addComment(String postId, String text) async {
    final uid = _uid;
    if (uid == null) throw StateError('Utilisateur non connecté.');
    if (text.trim().isEmpty) return;

    final profile = await ProfileService.instance.fetchProfile(uid);
    final user = AuthService.instance.currentUser;
    final authorName = profile?.fullName.isNotEmpty == true
        ? profile!.fullName
        : (user?.displayName?.isNotEmpty == true
            ? user!.displayName!
            : (user?.email ?? 'Utilisateur'));

    final comment = PostComment(
      id: '',
      authorId: uid,
      authorName: authorName,
      authorPhotoUrl: profile?.photoUrl,
      text: text.trim(),
    );

    final batch = _db.batch();
    batch.set(_posts.doc(postId).collection('comments').doc(), comment.toMap());
    batch.update(_posts.doc(postId), {
      'commentCount': FieldValue.increment(1),
    });
    await batch.commit().timeout(_timeout);
  }

  // ---------------------------------------------------------------------
  // Abonnements
  // ---------------------------------------------------------------------

  DocumentReference<Map<String, dynamic>> _followingDoc(
          String uid, String targetUid) =>
      _db.collection('users').doc(uid).collection('following').doc(targetUid);

  DocumentReference<Map<String, dynamic>> _followerDoc(
          String targetUid, String uid) =>
      _db.collection('users').doc(targetUid).collection('followers').doc(uid);

  Stream<bool> watchFollowing(String targetUid) {
    final uid = _uid;
    if (uid == null || uid == targetUid) return Stream.value(false);
    return _followingDoc(uid, targetUid)
        .snapshots()
        .map((s) => s.exists)
        .handleError((_) => false);
  }

  Future<void> toggleFollow(String targetUid) async {
    final uid = _uid;
    if (uid == null || uid == targetUid) return;
    final followingRef = _followingDoc(uid, targetUid);
    final followerRef = _followerDoc(targetUid, uid);

    final snap = await followingRef.get().timeout(_timeout);
    final batch = _db.batch();
    if (snap.exists) {
      batch.delete(followingRef);
      batch.delete(followerRef);
    } else {
      final now = FieldValue.serverTimestamp();
      batch.set(followingRef, {'createdAt': now});
      batch.set(followerRef, {'createdAt': now});
    }
    await batch.commit().timeout(_timeout);
  }
}
