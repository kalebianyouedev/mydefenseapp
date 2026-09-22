import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../models/organisation.dart';
import '../models/post.dart';
import '../services/post_service.dart';
import '../widgets/auth_widgets.dart'
    show authPrimary, authInk, authMuted, authBorder, showAuthSnack;

/// Écran de création d'une publication (photo ou vidéo) pour le fil
/// "Posts", publiée au nom de [organisation].
class CreatePostScreen extends StatefulWidget {
  final Organisation organisation;

  const CreatePostScreen({super.key, required this.organisation});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _picker = ImagePicker();
  final _captionCtrl = TextEditingController();

  File? _mediaFile;
  PostMediaType? _mediaType;
  bool _posting = false;

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() {
      _mediaFile = File(picked.path);
      _mediaType = PostMediaType.image;
    });
  }

  Future<void> _pickVideo() async {
    final picked = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 3),
    );
    if (picked == null) return;
    setState(() {
      _mediaFile = File(picked.path);
      _mediaType = PostMediaType.video;
    });
  }

  Future<void> _publish() async {
    final mediaFile = _mediaFile;
    final mediaType = _mediaType;
    if (mediaFile == null || mediaType == null) {
      showAuthSnack(context, 'Choisissez une photo ou une vidéo.');
      return;
    }
    setState(() => _posting = true);
    try {
      await PostService.instance.createPost(
        mediaFile: mediaFile,
        mediaType: mediaType,
        caption: _captionCtrl.text,
        organisationId: widget.organisation.id,
        organisationName: widget.organisation.name,
      );
      if (!mounted) return;
      showAuthSnack(context, 'Publication envoyée !');
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        showAuthSnack(context, "Échec de la publication. Réessayez.");
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: authInk,
        title: Text(
          'Nouvelle publication',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: authInk,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F4F6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.apartment_outlined,
                      size: 18, color: authMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Publier en tant que ${widget.organisation.name}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: authInk,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _mediaType == PostMediaType.video
                  ? _pickVideo
                  : _pickPhoto,
              child: Container(
                height: 320,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4F6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: authBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: _mediaFile == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_photo_alternate_outlined,
                                size: 40, color: authMuted),
                            const SizedBox(height: 10),
                            Text(
                              'Ajouter une photo ou une vidéo',
                              style: GoogleFonts.poppins(
                                  fontSize: 13.5, color: authMuted),
                            ),
                          ],
                        ),
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_mediaType == PostMediaType.image)
                            Image.file(_mediaFile!, fit: BoxFit.cover)
                          else
                            Container(
                              color: Colors.black87,
                              alignment: Alignment.center,
                              child: const Icon(Icons.videocam_rounded,
                                  size: 56, color: Colors.white70),
                            ),
                          Positioned(
                            right: 10,
                            top: 10,
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _mediaFile = null;
                                _mediaType = null;
                              }),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    size: 18, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickPhoto,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: authBorder),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.photo_outlined,
                        size: 18, color: authInk),
                    label: Text('Photo',
                        style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: authInk)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickVideo,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: authBorder),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.videocam_outlined,
                        size: 18, color: authInk),
                    label: Text('Vidéo',
                        style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: authInk)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _captionCtrl,
              maxLines: 4,
              style: GoogleFonts.poppins(fontSize: 14, color: authInk),
              decoration: InputDecoration(
                hintText: 'Écrire une légende...',
                hintStyle: GoogleFonts.poppins(fontSize: 14, color: authMuted),
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: authBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: authBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: authPrimary, width: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _posting ? null : _publish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: authPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _posting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Publier',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
