import 'dart:ui';

import 'package:flutter/material.dart';

import 'auth_widgets.dart' show authInk;

/// Affiche d'événement entièrement visible (jamais rognée) : l'image est
/// centrée en entier, sur un fond flou et assombri de la même image qui
/// remplit le cadre. Les affiches verticales restent ainsi lisibles
/// (titre, date, artistes) quel que soit le format du cadre.
/// Utilisé aussi pour les couvertures de vote et les photos de candidats.
class EventCover extends StatelessWidget {
  final String? imageUrl;
  final double fallbackIconSize;
  final IconData fallbackIcon;

  const EventCover({
    super.key,
    required this.imageUrl,
    this.fallbackIconSize = 44,
    this.fallbackIcon = Icons.festival_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null || url.isEmpty) return _fallback();
    return Stack(
      fit: StackFit.expand,
      children: [
        // Fond : même image, agrandie et floutée.
        ClipRect(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(color: authInk),
            ),
          ),
        ),
        ColoredBox(color: Colors.black.withValues(alpha: 0.18)),
        // Premier plan : l'affiche entière.
        Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white70),
                  ),
                ),
          errorBuilder: (_, _, _) => _fallback(),
        ),
      ],
    );
  }

  Widget _fallback() {
    return ColoredBox(
      color: authInk,
      child: Center(
        child: Icon(fallbackIcon, size: fallbackIconSize, color: Colors.white70),
      ),
    );
  }
}
