import 'package:flutter/material.dart';

import '../../models/event.dart';
import '../../models/vote_campaign.dart';
import '../admin_service.dart';
import '../admin_widgets.dart';

/// Tous les événements (tous statuts) : masquer du public ou supprimer.
class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  String _query = '';
  bool _hiddenOnly = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Event>>(
      stream: AdminService.instance.watchEvents(),
      builder: (context, snap) {
        final all = snap.data ?? const <Event>[];
        final q = _query.trim().toLowerCase();
        final list = all.where((e) {
          if (_hiddenOnly && !e.hiddenByAdmin) return false;
          if (q.isEmpty) return true;
          return e.title.toLowerCase().contains(q) ||
              e.organisationName.toLowerCase().contains(q) ||
              e.city.toLowerCase().contains(q);
        }).toList();
        return _ContentScaffold(
          title: 'Événements',
          subtitle: 'Tous les événements, tous statuts confondus',
          searchHint: 'Titre, organisation, ville…',
          onSearch: (v) => setState(() => _query = v),
          hiddenOnly: _hiddenOnly,
          onHiddenOnly: (v) => setState(() => _hiddenOnly = v),
          total: all.length,
          hiddenCount: all.where((e) => e.hiddenByAdmin).length,
          error: snap.error,
          loading: !snap.hasData,
          empty: list.isEmpty,
          rows: [
            for (final e in list)
              _ContentRow(
                title: e.title,
                imageUrl: e.coverImageUrl,
                organisation: e.organisationName,
                certified: e.organisationCertified,
                hidden: e.hiddenByAdmin,
                status: switch (e.status) {
                  EventStatus.published => ('Publié', AdminColors.success),
                  EventStatus.draft => ('Brouillon', AdminColors.muted),
                  EventStatus.cancelled => ('Annulé', AdminColors.danger),
                },
                details: [
                  if (e.city.isNotEmpty) e.city,
                  '${e.views} vues',
                  '${e.likeCount} j\'aime',
                  if (e.boosts > 0) '⚡ ${e.boosts} boost(s) · ${formatXaf(e.boostAmount)}',
                  if (e.createdAt != null) 'créé le ${adminDate.format(e.createdAt!)}',
                ].join(' · '),
                onToggleHidden: () => runAdminAction(
                  context,
                  () => AdminService.instance.setEventHidden(e, !e.hiddenByAdmin),
                  success: e.hiddenByAdmin ? 'Événement rétabli.' : 'Événement masqué du public.',
                ),
                onDelete: () async {
                  final ok = await adminConfirm(context,
                      title: 'Supprimer « ${e.title} » ?',
                      message: "L'événement est supprimé définitivement. Les billets déjà vendus restent dans l'historique des commandes.",
                      confirmLabel: 'Supprimer');
                  if (!ok || !context.mounted) return;
                  await runAdminAction(context, () => AdminService.instance.deleteEvent(e), success: 'Événement supprimé.');
                },
              ),
          ],
        );
      },
    );
  }
}

/// Toutes les campagnes de vote : masquer du public ou supprimer.
class VotesPage extends StatefulWidget {
  const VotesPage({super.key});

  @override
  State<VotesPage> createState() => _VotesPageState();
}

class _VotesPageState extends State<VotesPage> {
  String _query = '';
  bool _hiddenOnly = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<VoteCampaign>>(
      stream: AdminService.instance.watchCampaigns(),
      builder: (context, snap) {
        final all = snap.data ?? const <VoteCampaign>[];
        final q = _query.trim().toLowerCase();
        final list = all.where((c) {
          if (_hiddenOnly && !c.hiddenByAdmin) return false;
          if (q.isEmpty) return true;
          return c.title.toLowerCase().contains(q) || c.organisationName.toLowerCase().contains(q);
        }).toList();
        return _ContentScaffold(
          title: 'Votes',
          subtitle: 'Toutes les campagnes de vote',
          searchHint: 'Titre, organisation…',
          onSearch: (v) => setState(() => _query = v),
          hiddenOnly: _hiddenOnly,
          onHiddenOnly: (v) => setState(() => _hiddenOnly = v),
          total: all.length,
          hiddenCount: all.where((c) => c.hiddenByAdmin).length,
          error: snap.error,
          loading: !snap.hasData,
          empty: list.isEmpty,
          rows: [
            for (final c in list)
              _ContentRow(
                title: c.title,
                imageUrl: c.coverImageUrl,
                organisation: c.organisationName,
                certified: c.organisationCertified,
                hidden: c.hiddenByAdmin,
                status: switch (c.status) {
                  VoteCampaignStatus.active => ('Ouvert', AdminColors.success),
                  VoteCampaignStatus.draft => ('Brouillon', AdminColors.muted),
                  VoteCampaignStatus.ended => ('Terminé', AdminColors.info),
                  VoteCampaignStatus.cancelled => ('Annulé', AdminColors.danger),
                },
                details: [
                  if (c.startsAt != null) 'ouverture ${adminDate.format(c.startsAt!)}',
                  if (c.endsAt != null) 'clôture ${adminDate.format(c.endsAt!)}',
                  if (c.createdAt != null) 'créé le ${adminDate.format(c.createdAt!)}',
                ].join(' · '),
                onToggleHidden: () => runAdminAction(
                  context,
                  () => AdminService.instance.setCampaignHidden(c, !c.hiddenByAdmin),
                  success: c.hiddenByAdmin ? 'Vote rétabli.' : 'Vote masqué du public.',
                ),
                onDelete: () async {
                  final ok = await adminConfirm(context,
                      title: 'Supprimer « ${c.title} » ?',
                      message: "La campagne est supprimée définitivement. Les achats de votes restent dans l'historique.",
                      confirmLabel: 'Supprimer');
                  if (!ok || !context.mounted) return;
                  await runAdminAction(context, () => AdminService.instance.deleteCampaign(c), success: 'Vote supprimé.');
                },
              ),
          ],
        );
      },
    );
  }
}

class _ContentScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final String searchHint;
  final ValueChanged<String> onSearch;
  final bool hiddenOnly;
  final ValueChanged<bool> onHiddenOnly;
  final int total;
  final int hiddenCount;
  final Object? error;
  final bool loading;
  final bool empty;
  final List<Widget> rows;

  const _ContentScaffold({
    required this.title,
    required this.subtitle,
    required this.searchHint,
    required this.onSearch,
    required this.hiddenOnly,
    required this.onHiddenOnly,
    required this.total,
    required this.hiddenCount,
    required this.error,
    required this.loading,
    required this.empty,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        AdminPageHeader(title: title, subtitle: subtitle, actions: [AdminSearchField(hint: searchHint, onChanged: onSearch)]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: AdminFilterTabs<bool>(
            selected: hiddenOnly,
            onSelected: onHiddenOnly,
            tabs: [(false, 'Tous', total), (true, 'Masqués', hiddenCount)],
          ),
        ),
        const SizedBox(height: 18),
        if (error != null)
          AdminError(error: error!)
        else if (loading)
          const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator()))
        else if (empty)
          const AdminEmpty(icon: Icons.search_off_rounded, text: 'Aucun résultat.')
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: AdminCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: AdminColors.border),
                    rows[i],
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ContentRow extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final String organisation;
  final bool certified;
  final bool hidden;
  final (String, Color) status;
  final String details;
  final VoidCallback onToggleHidden;
  final VoidCallback onDelete;

  const _ContentRow({
    required this.title,
    required this.imageUrl,
    required this.organisation,
    required this.certified,
    required this.hidden,
    required this.status,
    required this.details,
    required this.onToggleHidden,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 64,
              height: 64,
              color: AdminColors.background,
              child: url != null && url.startsWith('http')
                  ? Image.network(url, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported_outlined, color: AdminColors.muted))
                  : const Icon(Icons.image_outlined, color: AdminColors.muted),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: adminText(14, weight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    AdminChip(label: status.$1, color: status.$2),
                    if (hidden) ...[
                      const SizedBox(width: 6),
                      const AdminChip(label: 'Masqué', color: AdminColors.danger, icon: Icons.visibility_off_outlined),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(organisation, style: adminText(12.5, weight: FontWeight.w600, color: AdminColors.muted)),
                    if (certified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, size: 14, color: AdminColors.info),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(details, maxLines: 1, overflow: TextOverflow.ellipsis, style: adminText(12, color: AdminColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AdminActionButton(
            label: hidden ? 'Rétablir' : 'Masquer',
            icon: hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: hidden ? AdminColors.success : AdminColors.warning,
            onPressed: onToggleHidden,
          ),
          const SizedBox(width: 4),
          IconButton(tooltip: 'Supprimer', onPressed: onDelete, icon: const Icon(Icons.delete_outline, color: AdminColors.danger)),
        ],
      ),
    );
  }
}
