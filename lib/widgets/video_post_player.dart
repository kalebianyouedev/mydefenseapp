import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Lecteur vidéo en boucle, muet par défaut, pour une publication du
/// fil "Posts". `video_player` n'a pas d'implémentation Windows/Linux :
/// sur ces plateformes on affiche un aperçu statique au lieu de planter.
class VideoPostPlayer extends StatefulWidget {
  final String url;
  final bool isActive;

  const VideoPostPlayer({
    super.key,
    required this.url,
    required this.isActive,
  });

  static bool get isSupported =>
      kIsWeb || !(Platform.isWindows || Platform.isLinux);

  @override
  State<VideoPostPlayer> createState() => _VideoPostPlayerState();
}

class _VideoPostPlayerState extends State<VideoPostPlayer> {
  VideoPlayerController? _controller;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    if (VideoPostPlayer.isSupported) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..setLooping(true)
        ..setVolume(0)
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() {});
          if (widget.isActive) _controller?.play();
        });
    }
  }

  @override
  void didUpdateWidget(covariant VideoPostPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (widget.isActive && !controller.value.isPlaying) {
      controller.play();
    } else if (!widget.isActive && controller.value.isPlaying) {
      controller.pause();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _controller?.setVolume(_muted ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!VideoPostPlayer.isSupported ||
        controller == null ||
        !controller.value.isInitialized) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: Icon(
          Icons.play_circle_outline,
          size: 64,
          color: Colors.white.withOpacity(0.7),
        ),
      );
    }

    return GestureDetector(
      onTap: _toggleMute,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
          Positioned(
            right: 14,
            bottom: 14,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
