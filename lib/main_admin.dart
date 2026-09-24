import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'admin/admin_login_screen.dart';
import 'admin/admin_prefs.dart';
import 'admin/admin_service.dart';
import 'admin/admin_shell.dart';
import 'admin/admin_widgets.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';

/// Application d'administration (desktop Windows / macOS / web).
/// Même projet Firebase que l'app mobile, lancée avec :
///   flutter run -d windows -t lib/main_admin.dart
///   flutter build windows -t lib/main_admin.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('fr_FR');
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ça Bouge Où ? · Administration',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: AdminColors.primary, brightness: Brightness.light),
        scaffoldBackgroundColor: AdminColors.background,
        textTheme: GoogleFonts.nunitoTextTheme(),
      ),
      home: const _AdminGate(),
    );
  }
}

/// Session déjà ouverte et toujours administrateur → espace admin ;
/// sinon écran de connexion.
class _AdminGate extends StatelessWidget {
  const _AdminGate();

  Future<bool> _check() async {
    if (AuthService.instance.currentUser == null) return false;
    // Sans « Se souvenir de moi », la session ne survit pas à la
    // fermeture de l'application.
    final prefs = await AdminPrefs.load();
    if (!prefs.remember) {
      await AuthService.instance.signOut();
      return false;
    }
    final ok = await AdminService.instance.currentUserIsAdmin();
    if (!ok) await AuthService.instance.signOut();
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _check(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            backgroundColor: AdminColors.sidebar,
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }
        return snap.data! ? const AdminShell() : const AdminLoginScreen();
      },
    );
  }
}
