import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../welcome_screen.dart';
import '../widgets/auth_widgets.dart' show authPrimary, authInk, authMuted;
import 'organisation_hub_screen.dart';
import 'placeholder_screen.dart';
import 'profile_screen.dart';

/// Écran "Mon compte" : profil résumé + navigation vers chaque
/// sous-fonctionnalité (Mon profil, Favoris, Communauté, Portefeuille,
/// Paramètres, Points de vente, Noter l'app, Aide et support).
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await AuthService.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  void _openOrganisationHub(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OrganisationHubScreen()),
    );
  }

  void _openPlaceholder(
    BuildContext context, {
    required String title,
    required IconData icon,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlaceholderScreen(title: title, icon: icon),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = AuthService.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 130),
          children: [
            Center(
              child: Text(
                'Mon compte',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: authInk,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _ProfileHeader(
              user: user,
              onEdit: () => _openProfile(context),
            ),
            const SizedBox(height: 28),
            _SectionLabel('MON ESPACE'),
            const SizedBox(height: 6),
            _AccountRow(
              icon: Icons.person_outline_rounded,
              label: 'Mon profil',
              onTap: () => _openProfile(context),
            ),
            _AccountRow(
              icon: Icons.favorite_border_rounded,
              label: 'Mes favoris',
              onTap: () => _openPlaceholder(
                context,
                title: 'Mes favoris',
                icon: Icons.favorite_border_rounded,
              ),
            ),
            _AccountRow(
              icon: Icons.groups_outlined,
              label: 'Ma communauté',
              onTap: () => _openPlaceholder(
                context,
                title: 'Ma communauté',
                icon: Icons.groups_outlined,
              ),
            ),
            _AccountRow(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Mon portefeuille',
              onTap: () => _openPlaceholder(
                context,
                title: 'Mon portefeuille',
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFEDEDF1), height: 1),
            const SizedBox(height: 20),
            _SectionLabel('ORGANISATION'),
            const SizedBox(height: 6),
            _AccountRow(
              icon: Icons.dashboard_customize_outlined,
              label: 'Tableau de bord',
              onTap: () => _openOrganisationHub(context),
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFEDEDF1), height: 1),
            const SizedBox(height: 20),
            _SectionLabel('PARAMÈTRES ET AIDE'),
            const SizedBox(height: 6),
            _AccountRow(
              icon: Icons.settings_outlined,
              label: 'Paramètres',
              onTap: () => _openPlaceholder(
                context,
                title: 'Paramètres',
                icon: Icons.settings_outlined,
              ),
            ),
            _AccountRow(
              icon: Icons.storefront_outlined,
              label: 'Points de vente',
              onTap: () => _openPlaceholder(
                context,
                title: 'Points de vente',
                icon: Icons.storefront_outlined,
              ),
            ),
            _AccountRow(
              icon: Icons.star_border_rounded,
              label: "Noter l'App",
              onTap: () => _openPlaceholder(
                context,
                title: "Noter l'App",
                icon: Icons.star_border_rounded,
              ),
            ),
            _AccountRow(
              icon: Icons.support_agent_outlined,
              label: 'Aide et support',
              onTap: () => _openPlaceholder(
                context,
                title: 'Aide et support',
                icon: Icons.support_agent_outlined,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFEDEDF1), height: 1),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => _signOut(context),
              child: Row(
                children: [
                  const Icon(Icons.logout_rounded,
                      size: 20, color: authPrimary),
                  const SizedBox(width: 12),
                  Text(
                    'Se déconnecter',
                    style: GoogleFonts.poppins(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: authPrimary,
                    ),
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

class _ProfileHeader extends StatelessWidget {
  final User? user;
  final VoidCallback onEdit;

  const _ProfileHeader({required this.user, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final uid = user?.uid;
    if (uid == null) {
      return _headerContent(context, null);
    }
    return StreamBuilder<UserProfile?>(
      stream: ProfileService.instance.watchProfile(uid),
      builder: (context, snapshot) {
        return _headerContent(context, snapshot.data);
      },
    );
  }

  Widget _headerContent(BuildContext context, UserProfile? profile) {
    final displayName = profile?.fullName.isNotEmpty == true
        ? profile!.fullName
        : (user?.displayName?.isNotEmpty == true
            ? user!.displayName!
            : 'Mon compte');
    final email = user?.email ?? '';
    final avatarImage = imageProviderFromPath(profile?.photoUrl);
    final initials = _initialsFor(displayName, email);

    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: authPrimary.withOpacity(0.12),
          backgroundImage: avatarImage,
          child: avatarImage == null
              ? Text(
                  initials,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: authPrimary,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: authInk,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 12.5, color: authMuted),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 20, color: authInk),
        ),
      ],
    );
  }

  String _initialsFor(String name, String email) {
    if (name.isNotEmpty && name != 'Mon compte') {
      final parts = name.trim().split(RegExp(r'\s+'));
      final a = parts.isNotEmpty && parts.first.isNotEmpty
          ? parts.first[0]
          : '';
      final b = parts.length > 1 && parts.last.isNotEmpty
          ? parts.last[0]
          : '';
      final result = (a + b).toUpperCase();
      if (result.isNotEmpty) return result;
    }
    return email.isNotEmpty ? email[0].toUpperCase() : '?';
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: authMuted,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AccountRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 22, color: authInk),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: authInk,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 22, color: authMuted),
          ],
        ),
      ),
    );
  }
}
