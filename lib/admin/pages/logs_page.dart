import 'package:flutter/material.dart';

import '../admin_service.dart';
import '../admin_widgets.dart';

/// Journal : chaque action d'un administrateur (qui, quoi, quand).
class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  String _query = '';

  static Color _color(String action) {
    final a = action.toLowerCase();
    if (a.contains('supprim') || a.contains('refus') || a.contains('bloqu') && !a.contains('débloqu')) {
      return AdminColors.danger;
    }
    if (a.contains('payé') || a.contains('certifi') || a.contains('débloqu') || a.contains('rétabli')) {
      return AdminColors.success;
    }
    if (a.contains('validé')) return AdminColors.info;
    return AdminColors.muted;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminLogEntry>>(
      stream: AdminService.instance.watchLogs(),
      builder: (context, snap) {
        final q = _query.trim().toLowerCase();
        final list = (snap.data ?? const <AdminLogEntry>[]).where((l) {
          if (q.isEmpty) return true;
          return l.action.toLowerCase().contains(q) ||
              l.target.toLowerCase().contains(q) ||
              l.adminEmail.toLowerCase().contains(q) ||
              (l.details?.toLowerCase().contains(q) ?? false);
        }).toList();
        return ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            AdminPageHeader(
              title: 'Journal',
              subtitle: 'Historique des 300 dernières actions des administrateurs',
              actions: [AdminSearchField(hint: 'Action, cible, admin…', onChanged: (v) => setState(() => _query = v))],
            ),
            if (snap.hasError)
              AdminError(error: snap.error!)
            else if (!snap.hasData)
              const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator()))
            else if (list.isEmpty)
              const AdminEmpty(icon: Icons.history_rounded, text: 'Aucune action enregistrée.')
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: AdminCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < list.length; i++) ...[
                        if (i > 0) const Divider(height: 1, color: AdminColors.border),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 170,
                                child: Text(list[i].at != null ? adminDate.format(list[i].at!) : '—',
                                    style: adminText(12.5, color: AdminColors.muted)),
                              ),
                              SizedBox(
                                width: 210,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: AdminChip(label: list[i].action, color: _color(list[i].action)),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(list[i].target, style: adminText(13.5, weight: FontWeight.w600)),
                                    if (list[i].details?.isNotEmpty == true)
                                      Text(list[i].details!, style: adminText(12, color: AdminColors.muted)),
                                  ],
                                ),
                              ),
                              Text(list[i].adminEmail, style: adminText(12.5, color: AdminColors.muted)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
