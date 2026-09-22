import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../models/post.dart';
import '../services/auth_service.dart';
import '../services/post_service.dart';
import '../services/profile_service.dart';
import '../widgets/auth_widgets.dart' show authPrimary, showAuthSnack;
import '../widgets/video_post_player.dart';
import 'comments_sheet.dart';
import 'organisations_screen.dart';

/// Fil "Posts" façon reels : défilement vertical plein écran de
/// publications (photo ou vidéo) avec like, commentaires, sauvegarde,
/// partage, abonnement à l'auteur et republication.
class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  final _pageController = PageController();
  int _activeIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _openCreatePost() => openPostFlow(context);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<List<Post>>(
        stream: PostService.instance.watchFeed(),
        builder: (context, snapshot) {
          final posts = snapshot.data ?? const [];
          final loading =
              snapshot.connectionState == ConnectionState.waiting &&
                  posts.isEmpty;

          if (loading) {
            return const Center(
              child: CircularProgressIndicator(color: authPrimary),
            );
          }

          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.movie_creation_outlined,
                      size: 48, color: Colors.white.withOpacity(0.7)),
                  const SizedBox(height: 14),
                  Text(
                    'Aucune publication pour le moment.',
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: Colors.white),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: _openCreatePost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: authPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: Text('Publier',
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            );
          }

          return Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: posts.length,
                onPageChanged: (i) => setState(() => _activeIndex = i),
                itemBuilder: (context, index) => _PostCard(
                  post: posts[index],
                  isActive: index == _activeIndex,
                ),
              ),
              Positioned(
                top: 8,
                right: 12,
                child: SafeArea(
                  bottom: false,
                  child: _RoundIconButton(
                    icon: Icons.add,
                    onTap: _openCreatePost,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _PostCard extends StatefulWidget {
  final Post post;
  final bool isActive;

  const _PostCard({required this.post, required this.isActive});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _showHeart = false;

  String get _uid => AuthService.instance.currentUser?.uid ?? '';

  Future<void> _handleLike() async {
    HapticFeedback.lightImpact();
    try {
      await PostService.instance.toggleLike(widget.post.id);
    } catch (_) {
      if (mounted) showAuthSnack(context, "Action impossible pour l'instant.");
    }
  }

  void _handleDoubleTapLike() {
    setState(() => _showHeart = true);
    _handleLike();
    Future.delayed(const Duration(milliseconds: 550), () {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  Future<void> _handleSave() async {
    try {
      await PostService.instance.toggleSave(widget.post.id);
    } catch (_) {
      if (mounted) showAuthSnack(context, "Action impossible pour l'instant.");
    }
  }

  Future<void> _handleFollow() async {
    if (widget.post.authorId == _uid) return;
    try {
      await PostService.instance.toggleFollow(widget.post.authorId);
    } catch (_) {
      if (mounted) showAuthSnack(context, "Action impossible pour l'instant.");
    }
  }

  Future<void> _handleShare() async {
    try {
      await Share.share(
        widget.post.caption.isNotEmpty
            ? '${widget.post.caption}\n${widget.post.mediaUrl}'
            : widget.post.mediaUrl,
      );
      await PostService.instance.registerShare(widget.post.id);
    } catch (_) {
      if (mounted) showAuthSnack(context, 'Partage impossible.');
    }
  }

  Future<void> _handleRepost() async {
    try {
      await PostService.instance.repost(widget.post);
      if (mounted) showAuthSnack(context, 'Republié sur votre profil.');
    } catch (_) {
      if (mounted) showAuthSnack(context, 'Republication impossible.');
    }
  }

  Future<void> _handleVote() async {
    HapticFeedback.lightImpact();
    try {
      await PostService.instance.toggleVote(widget.post.id);
    } catch (_) {
      if (mounted) showAuthSnack(context, "Action impossible pour l'instant.");
    }
  }

  void _openComments() {
    showCommentsSheet(context, widget.post.id);
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final isOwnPost = post.authorId == _uid;

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onDoubleTap: _handleDoubleTapLike,
          child: post.mediaType == PostMediaType.video
              ? VideoPostPlayer(url: post.mediaUrl, isActive: widget.isActive)
              : Image.network(
                  post.mediaUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    color: Colors.black87,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined,
                        size: 48, color: Colors.white38),
                  ),
                ),
        ),
        // Voile dégradé bas pour la lisibilité du texte.
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.55),
                ],
                stops: const [0.6, 1.0],
              ),
            ),
          ),
        ),
        AnimatedOpacity(
          opacity: _showHeart ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: const Center(
            child: Icon(Icons.favorite, color: Colors.white, size: 100),
          ),
        ),
        if (post.isRepost)
          Positioned(
            top: 8,
            left: 12,
            child: SafeArea(
              bottom: false,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.repeat_rounded,
                        size: 13, color: Colors.white70),
                    const SizedBox(width: 5),
                    Text(
                      'Republié de ${post.originalAuthorName ?? ''}',
                      style: GoogleFonts.poppins(
                          fontSize: 11.5, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // Colonne d'actions à droite.
        Positioned(
          right: 10,
          bottom: 110,
          child: Column(
            children: [
              _AuthorAvatar(post: post, onFollow: _handleFollow),
              const SizedBox(height: 22),
              StreamBuilder<bool>(
                stream: PostService.instance.watchLiked(post.id),
                builder: (context, snap) {
                  final liked = snap.data ?? false;
                  return _ActionButton(
                    icon: liked ? Icons.favorite : Icons.favorite_border,
                    color: liked ? authPrimary : Colors.white,
                    label: '${post.likeCount}',
                    onTap: _handleLike,
                  );
                },
              ),
              const SizedBox(height: 20),
              _ActionButton(
                icon: Icons.mode_comment_outlined,
                color: Colors.white,
                label: '${post.commentCount}',
                onTap: _openComments,
              ),
              const SizedBox(height: 20),
              StreamBuilder<bool>(
                stream: PostService.instance.watchSaved(post.id),
                builder: (context, snap) {
                  final saved = snap.data ?? false;
                  return _ActionButton(
                    icon: saved ? Icons.bookmark : Icons.bookmark_border,
                    color: saved ? const Color(0xFFFFC53D) : Colors.white,
                    label: '${post.saveCount}',
                    onTap: _handleSave,
                  );
                },
              ),
              const SizedBox(height: 20),
              _ActionButton(
                icon: Icons.reply_rounded,
                color: Colors.white,
                label: '${post.shareCount}',
                onTap: _handleShare,
              ),
              const SizedBox(height: 20),
              _ActionButton(
                icon: Icons.repeat_rounded,
                color: Colors.white,
                label: '${post.repostCount}',
                onTap: isOwnPost ? null : _handleRepost,
              ),
              const SizedBox(height: 20),
              StreamBuilder<bool>(
                stream: PostService.instance.watchVoted(post.id),
                builder: (context, snap) {
                  final voted = snap.data ?? false;
                  return _ActionButton(
                    icon: Icons.how_to_vote_rounded,
                    color: voted ? authPrimary : Colors.white,
                    label: '${post.voteCount}',
                    onTap: _handleVote,
                  );
                },
              ),
            ],
          ),
        ),
        // Infos auteur + légende en bas à gauche.
        Positioned(
          left: 16,
          right: 90,
          bottom: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '@${post.authorName}',
                    style: GoogleFonts.poppins(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  if (!isOwnPost) ...[
                    const SizedBox(width: 10),
                    StreamBuilder<bool>(
                      stream: PostService.instance.watchFollowing(
                        post.authorId,
                      ),
                      builder: (context, snap) {
                        final following = snap.data ?? false;
                        return GestureDetector(
                          onTap: _handleFollow,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: following
                                  ? Colors.white.withOpacity(0.15)
                                  : authPrimary,
                              borderRadius: BorderRadius.circular(20),
                              border: following
                                  ? Border.all(color: Colors.white70)
                                  : null,
                            ),
                            child: Text(
                              following ? 'Abonné(e)' : 'Suivre',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
              if (post.caption.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  post.caption,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.white),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  final Post post;
  final VoidCallback onFollow;

  const _AuthorAvatar({required this.post, required this.onFollow});

  @override
  Widget build(BuildContext context) {
    final avatar = imageProviderFromPath(post.authorPhotoUrl);
    return GestureDetector(
      onTap: onFollow,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: CircleAvatar(
          radius: 21,
          backgroundColor: authPrimary.withOpacity(0.3),
          backgroundImage: avatar,
          child: avatar == null
              ? Text(
                  post.authorName.isNotEmpty
                      ? post.authorName[0].toUpperCase()
                      : '?',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
