import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/post_comment.dart';
import '../services/post_service.dart';
import '../services/profile_service.dart';
import '../widgets/auth_widgets.dart'
    show authPrimary, authInk, authMuted, authBorder, showAuthSnack;

/// Ouvre la feuille de commentaires d'une publication.
Future<void> showCommentsSheet(BuildContext context, String postId) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _CommentsSheet(postId: postId),
  );
}

class _CommentsSheet extends StatefulWidget {
  final String postId;

  const _CommentsSheet({required this.postId});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await PostService.instance.addComment(widget.postId, text);
      _controller.clear();
    } catch (_) {
      if (mounted) {
        showAuthSnack(context, "Impossible d'envoyer le commentaire.");
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: authBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Commentaires',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: authInk,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: authBorder),
            Expanded(
              child: StreamBuilder<List<PostComment>>(
                stream: PostService.instance.watchComments(widget.postId),
                builder: (context, snapshot) {
                  final comments = snapshot.data ?? const [];
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      comments.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(color: authPrimary),
                    );
                  }
                  if (comments.isEmpty) {
                    return Center(
                      child: Text(
                        'Aucun commentaire pour le moment.',
                        style:
                            GoogleFonts.nunito(fontSize: 13, color: authMuted),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    itemCount: comments.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, index) =>
                        _CommentTile(comment: comments[index]),
                  );
                },
              ),
            ),
            const Divider(height: 1, color: authBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: GoogleFonts.nunito(fontSize: 14, color: authInk),
                      decoration: InputDecoration(
                        hintText: 'Ajouter un commentaire...',
                        hintStyle:
                            GoogleFonts.nunito(fontSize: 14, color: authMuted),
                        filled: true,
                        fillColor: const Color(0xFFF4F4F6),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _sending
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: authPrimary,
                            ),
                          ),
                        )
                      : IconButton(
                          onPressed: _send,
                          icon: const Icon(Icons.send_rounded,
                              color: authPrimary),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final PostComment comment;

  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    final avatar = imageProviderFromPath(comment.authorPhotoUrl);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: authPrimary.withOpacity(0.12),
          backgroundImage: avatar,
          child: avatar == null
              ? Text(
                  comment.authorName.isNotEmpty
                      ? comment.authorName[0].toUpperCase()
                      : '?',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: authPrimary,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    comment.authorName,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: authInk,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (comment.createdAt != null)
                    Text(
                      DateFormat('dd/MM HH:mm').format(comment.createdAt!),
                      style: GoogleFonts.nunito(
                          fontSize: 11, color: authMuted),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                comment.text,
                style: GoogleFonts.nunito(fontSize: 13.5, color: authInk),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
