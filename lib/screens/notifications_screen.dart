import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/notification_service.dart';
import '../widgets/auth_widgets.dart' show authPrimary, authInk, authMuted, authBorder;

const _green = Color(0xFF1E9E6B);
const _red = Color(0xFFD93A3A);

IconData _icon(AppNotification n) => switch (n.type) {
      AppNotificationType.certification => n.positive == false ? Icons.gpp_bad_outlined : Icons.verified,
      AppNotificationType.withdrawal => Icons.payments_outlined,
      AppNotificationType.moderation => n.positive == false ? Icons.block : Icons.lock_open_rounded,
      AppNotificationType.info => Icons.notifications_outlined,
    };

Color _color(AppNotification n) => n.positive == true ? _green : (n.positive == false ? _red : authInk);

/// Liste des notifications envoyées par l'administrateur.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _latest = const [];

  @override
  void dispose() {
    // Ouvrir l'écran = tout est lu.
    NotificationService.instance.markAllRead(_latest);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("d MMM 'à' HH'h'mm", 'fr_FR');
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: authInk,
        title: Text('Notifications', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: authInk)),
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: NotificationService.instance.watchMine(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: authPrimary));
          final list = snap.data!;
          _latest = list;
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.notifications_none_rounded, size: 42, color: authMuted),
                    const SizedBox(height: 12),
                    Text('Aucune notification', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: authInk)),
                    const SizedBox(height: 6),
                    Text('Certification, retraits… les décisions de l\'administrateur apparaîtront ici en direct.',
                        textAlign: TextAlign.center, style: GoogleFonts.nunito(fontSize: 13, color: authMuted)),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final n = list[i];
              final color = _color(n);
              return Dismissible(
                key: ValueKey(n.id),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => NotificationService.instance.delete(n.id),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(color: _red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.delete_outline, color: _red),
                ),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: n.read ? Colors.white : color.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: n.read ? authBorder : color.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                        child: Icon(_icon(n), color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n.title, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: authInk)),
                            const SizedBox(height: 2),
                            Text(n.body, style: GoogleFonts.nunito(fontSize: 12.5, color: authMuted, height: 1.4)),
                            if (n.createdAt != null) ...[
                              const SizedBox(height: 6),
                              Text(fmt.format(n.createdAt!), style: GoogleFonts.nunito(fontSize: 11, color: authMuted)),
                            ],
                          ],
                        ),
                      ),
                      if (!n.read)
                        Container(
                          width: 9,
                          height: 9,
                          margin: const EdgeInsets.only(top: 4),
                          decoration: const BoxDecoration(color: authPrimary, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Cloche de l'accueil : pastille avec le nombre de notifications non
/// lues, mise à jour en temps réel.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotification>>(
      stream: NotificationService.instance.watchMine(),
      builder: (context, snap) {
        final unread = (snap.data ?? const <AppNotification>[]).where((n) => !n.read).length;
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(border: Border.all(color: authBorder), borderRadius: BorderRadius.circular(16)),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Center(child: Icon(Icons.notifications_outlined, size: 20, color: authInk)),
                  if (unread > 0)
                    Positioned(
                      top: 6,
                      right: 5,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 17),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: authPrimary,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(unread > 9 ? '9+' : '$unread',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Écoute les notifications en temps réel pendant que l'app est ouverte
/// et affiche une bannière dès qu'une nouvelle arrive (ex. l'admin vient
/// de certifier l'organisation ou de payer un retrait).
class LiveNotificationListener extends StatefulWidget {
  final Widget child;

  const LiveNotificationListener({super.key, required this.child});

  @override
  State<LiveNotificationListener> createState() => _LiveNotificationListenerState();
}

class _LiveNotificationListenerState extends State<LiveNotificationListener> {
  StreamSubscription<List<AppNotification>>? _sub;
  Set<String>? _known;

  @override
  void initState() {
    super.initState();
    _sub = NotificationService.instance.watchMine().listen((list) {
      final ids = list.map((n) => n.id).toSet();
      final known = _known;
      _known = ids;
      // Première émission = état au démarrage : on ne ré-affiche rien.
      if (known == null) return;
      final fresh = list.where((n) => !known.contains(n.id) && !n.read).toList();
      if (fresh.isNotEmpty && mounted) _show(fresh.first);
    });
  }

  void _show(AppNotification n) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 110),
        duration: const Duration(seconds: 6),
        backgroundColor: authInk,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            Icon(_icon(n), color: _color(n) == authInk ? Colors.white : _color(n)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.title, style: GoogleFonts.nunito(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Voir',
          textColor: Colors.white,
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
