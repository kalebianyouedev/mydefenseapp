import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'home_screen.dart';
import 'login_screen.dart';
import 'services/account_service.dart';
import 'services/auth_service.dart';
import 'widgets/auth_widgets.dart' show authPrimary, authInk, authMuted;

/// Point d'entrée commun après une connexion (email, Google, Apple,
/// inscription) ou au démarrage avec une session active : enregistre la
/// connexion puis refuse l'accès si l'administrateur a bloqué ou
/// supprimé le compte.
Future<void> enterApp(BuildContext context) async {
  final user = AuthService.instance.currentUser;
  if (user == null) return;

  AccountModeration moderation = AccountModeration.none;
  try {
    await AccountService.instance.recordSignIn();
    moderation = await AccountService.instance.fetchModeration(user.uid);
  } catch (_) {
    // Hors ligne : on laisse entrer, les règles Firestore bloquent de
    // toute façon les écritures d'un compte bloqué.
  }
  if (!context.mounted) return;

  if (moderation.blocked || moderation.deleted) {
    await AuthService.instance.signOut();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        icon: const Icon(Icons.block, color: authPrimary, size: 32),
        title: Text(moderation.deleted ? 'Compte supprimé' : 'Compte bloqué',
            style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w700, color: authInk)),
        content: Text(
          [
            moderation.deleted
                ? "Ce compte a été supprimé par l'administrateur."
                : "Ce compte a été suspendu par l'administrateur.",
            if (moderation.reason?.isNotEmpty == true) 'Motif : ${moderation.reason}',
            'Contactez le support si vous pensez qu\'il s\'agit d\'une erreur.',
          ].join('\n\n'),
          style: GoogleFonts.nunito(fontSize: 13, color: authMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
    return;
  }

  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const HomeScreen()),
    (route) => false,
  );
}
