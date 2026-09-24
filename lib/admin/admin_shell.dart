import 'package:flutter/material.dart';

import '../models/event.dart';
import '../models/organisation.dart';
import '../models/withdrawal.dart';
import '../services/auth_service.dart';
import 'admin_login_screen.dart';
import 'admin_prefs.dart';
import 'admin_service.dart';
import 'admin_widgets.dart';
import 'pages/content_pages.dart';
import 'pages/dashboard_page.dart';
import 'pages/logs_page.dart';
import 'pages/organisations_page.dart';
import 'pages/payments_page.dart';
import 'pages/users_page.dart';
import 'pages/withdrawals_page.dart';

enum AdminSection { dashboard, events, votes, organisations, users, payments, withdrawals, certifications, logs }

/// Structure de l'espace admin : menu latéral bleu Ça Bouge Où ? + page
/// courante.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  AdminSection _section = AdminSection.dashboard;

  void _go(AdminSection s) => setState(() => _section = s);

  Future<void> _signOut() async {
    final ok = await adminConfirm(context,
        title: 'Se déconnecter ?',
        message: "Vous devrez vous reconnecter pour accéder à l'espace administrateur.",
        confirmLabel: 'Se déconnecter',
        color: AdminColors.primary);
    if (!ok) return;
    final prefs = await AdminPrefs.load();
    await AdminPrefs.save(AdminPrefs(remember: false, email: prefs.email));
    await AuthService.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      (_) => false,
    );
  }

  Widget _page() {
    switch (_section) {
      case AdminSection.dashboard:
        return DashboardPage(onNavigate: _go);
      case AdminSection.events:
        return const EventsPage();
      case AdminSection.votes:
        return const VotesPage();
      case AdminSection.organisations:
        return const OrganisationsPage();
      case AdminSection.users:
        return const UsersPage();
      case AdminSection.payments:
        return const PaymentsPage();
      case AdminSection.withdrawals:
        return const WithdrawalsPage();
      case AdminSection.certifications:
        return const OrganisationsPage(certificationsOnly: true);
      case AdminSection.logs:
        return const LogsPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.background,
      body: Row(
        children: [
          _Sidebar(selected: _section, onSelected: _go, onSignOut: _signOut),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: KeyedSubtree(key: ValueKey(_section), child: _page()),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final AdminSection selected;
  final ValueChanged<AdminSection> onSelected;
  final VoidCallback onSignOut;

  const _Sidebar({required this.selected, required this.onSelected, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    final email = AuthService.instance.currentUser?.email ?? '';
    return Container(
      width: 210,
      color: AdminColors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Marque
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
            child: Row(
              children: [
                Container(
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                  child: Image.asset('assets/images/logo.png', errorBuilder: (_, _, _) => const SizedBox(width: 22)),
                ),
                const SizedBox(width: 10),
                Text.rich(TextSpan(
                  style: adminText(13.5, weight: FontWeight.w800, color: Colors.white),
                  children: [
                    const TextSpan(text: 'Ça '),
                    TextSpan(text: 'Bouge', style: adminText(13.5, weight: FontWeight.w800, color: const Color(0xFFFF4D7E))),
                    const TextSpan(text: ' Où ?'),
                  ],
                )),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _group('NAVIGATION'),
                _item(AdminSection.dashboard, Icons.grid_view_rounded, 'Tableau de bord'),
                StreamBuilder<List<Event>>(
                  stream: AdminService.instance.watchEvents(),
                  builder: (context, snap) =>
                      _item(AdminSection.events, Icons.calendar_month_outlined, 'Événements', count: snap.data?.length, neutral: true),
                ),
                _item(AdminSection.votes, Icons.emoji_events_outlined, 'Votes'),
                _item(AdminSection.organisations, Icons.apartment_rounded, 'Organisations'),
                const Padding(
                  padding: EdgeInsets.fromLTRB(10, 10, 10, 0),
                  child: Divider(color: Colors.white24, height: 1),
                ),
                const SizedBox(height: 10),
                _group('ADMINISTRATION'),
                _item(AdminSection.users, Icons.people_outline_rounded, 'Utilisateurs'),
                _item(AdminSection.payments, Icons.credit_card_rounded, 'Paiements'),
                StreamBuilder<List<Withdrawal>>(
                  stream: AdminService.instance.watchWithdrawals(),
                  builder: (context, snap) => _item(
                    AdminSection.withdrawals,
                    Icons.account_balance_wallet_outlined,
                    'Retraits',
                    count: snap.data?.where((w) => w.isOpen).length,
                  ),
                ),
                StreamBuilder<List<Organisation>>(
                  stream: AdminService.instance.watchOrganisations(),
                  builder: (context, snap) => _item(
                    AdminSection.certifications,
                    Icons.verified_user_outlined,
                    'Certifications',
                    count: snap.data?.where((o) => o.certificationRequested && !o.certified).length,
                  ),
                ),
                _item(AdminSection.logs, Icons.receipt_long_outlined, "Journal d'audit"),
              ],
            ),
          ),
          // Compte admin
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
            child: PopupMenuButton<String>(
              tooltip: 'Compte',
              offset: const Offset(0, -110),
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (v) {
                if (v == 'logout') onSignOut();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  enabled: false,
                  child: Text(email, style: adminText(12.5, color: AdminColors.muted)),
                ),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      const Icon(Icons.logout_rounded, size: 18, color: AdminColors.danger),
                      const SizedBox(width: 10),
                      Text('Se déconnecter', style: adminText(13.5, weight: FontWeight.w600, color: AdminColors.danger)),
                    ],
                  ),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.white,
                      child: Text('AP', style: adminText(10.5, weight: FontWeight.w800, color: AdminColors.primary)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Admin Plateforme',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: adminText(13, weight: FontWeight.w700, color: Colors.white)),
                    ),
                    const Icon(Icons.unfold_more_rounded, size: 18, color: Colors.white70),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _group(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(17, 6, 16, 6),
        child: Text(label, style: adminText(10, weight: FontWeight.w700, color: Colors.white60).copyWith(letterSpacing: 0.6)),
      );

  /// [neutral] : simple compteur (ex. nombre d'événements), sinon pastille
  /// rouge « à traiter » masquée à zéro.
  Widget _item(AdminSection section, IconData icon, String label, {int? count, bool neutral = false}) {
    final active = section == selected;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: Material(
        color: active ? AdminColors.sidebarActive : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          hoverColor: AdminColors.sidebarHover,
          onTap: () => onSelected(section),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Row(
              children: [
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(label,
                      style: adminText(13, weight: active ? FontWeight.w700 : FontWeight.w500, color: Colors.white)),
                ),
                if (count != null && (neutral || count > 0))
                  neutral
                      ? Text('$count', style: adminText(11, weight: FontWeight.w700, color: Colors.white))
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: AdminColors.accent, borderRadius: BorderRadius.circular(10)),
                          child: Text('$count', style: adminText(10.5, weight: FontWeight.w800, color: Colors.white)),
                        ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
