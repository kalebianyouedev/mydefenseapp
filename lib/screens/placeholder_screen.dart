import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/auth_widgets.dart' show authPrimary, authInk, authMuted;

/// Écran générique utilisé par les sous-fonctionnalités de "Mon compte"
/// qui n'ont pas encore leur propre implémentation (Favoris, Communauté,
/// Portefeuille, Paramètres, Points de vente, Aide et support...).
class PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final String message;

  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
    this.message = 'Cette section arrive bientôt.',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: authInk,
        title: Text(
          title,
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: authInk,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: authPrimary.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: authPrimary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: GoogleFonts.nunito(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: authInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.nunito(fontSize: 13.5, color: authMuted),
            ),
          ],
        ),
      ),
    );
  }
}
