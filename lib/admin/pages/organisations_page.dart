import 'package:flutter/material.dart';

import '../../models/organisation.dart';
import '../admin_service.dart';
import '../admin_widgets.dart';

enum _Filter { all, requests, certified, notCertified, blocked }

/// Organisations : certification (obligatoire pour les retraits),
/// blocage (masque leurs contenus et suspend retraits et publications)
/// et suppression (avec leurs événements et votes).
class OrganisationsPage extends StatefulWidget {
  /// Page « Certifications » : même liste, ouverte sur les demandes.
  final bool certificationsOnly;

  const OrganisationsPage({super.key, this.certificationsOnly = false});

  @override
  State<OrganisationsPage> createState() => _OrganisationsPageState();
}

class _OrganisationsPageState extends State<OrganisationsPage> {
  late _Filter _filter = widget.certificationsOnly ? _Filter.requests : _Filter.all;
  String _query = '';

  bool _test(Organisation o, _Filter f) => switch (f) {
        _Filter.all => true,
        _Filter.requests => o.certificationRequested && !o.certified,
        _Filter.certified => o.certified,
        _Filter.notCertified => !o.certified,
        _Filter.blocked => o.blocked,
      };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminUser>>(
      stream: AdminService.instance.watchUsers(),
      builder: (context, usersSnap) {
        final owners = {for (final u in usersSnap.data ?? const <AdminUser>[]) u.uid: u};
        return StreamBuilder<List<Organisation>>(
          stream: AdminService.instance.watchOrganisations(),
          builder: (context, snap) {
            final all = snap.data ?? const <Organisation>[];
            final q = _query.trim().toLowerCase();
            final list = all.where((o) {
              if (!_test(o, _filter)) return false;
              if (q.isEmpty) return true;
              final owner = owners[o.ownerId];
              return o.name.toLowerCase().contains(q) ||
                  (owner?.email.toLowerCase().contains(q) ?? false) ||
                  (owner?.name.toLowerCase().contains(q) ?? false);
            }).toList();
            return ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                AdminPageHeader(
                  title: widget.certificationsOnly ? 'Certifications' : 'Organisations',
                  subtitle: widget.certificationsOnly
                      ? 'Demandes de certification, nécessaires pour que les organisations puissent retirer'
                      : 'Certification, blocage et suppression',
                  actions: [AdminSearchField(hint: 'Nom, email du propriétaire…', onChanged: (v) => setState(() => _query = v))],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: AdminFilterTabs<_Filter>(
                    selected: _filter,
                    onSelected: (f) => setState(() => _filter = f),
                    tabs: [
                      for (final (f, label) in const [
                        (_Filter.all, 'Toutes'),
                        (_Filter.requests, 'Demandes de certification'),
                        (_Filter.certified, 'Certifiées'),
                        (_Filter.notCertified, 'Non certifiées'),
                        (_Filter.blocked, 'Bloquées'),
                      ])
                        (f, label, all.where((o) => _test(o, f)).length),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (snap.hasError)
                  AdminError(error: snap.error!)
                else if (!snap.hasData)
                  const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator()))
                else if (list.isEmpty)
                  const AdminEmpty(icon: Icons.apartment_outlined, text: 'Aucune organisation dans cette liste.')
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: AdminCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < list.length; i++) ...[
                            if (i > 0) const Divider(height: 1, color: AdminColors.border),
                            _OrganisationRow(organisation: list[i], owner: owners[list[i].ownerId]),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _OrganisationRow extends StatelessWidget {
  final Organisation organisation;
  final AdminUser? owner;

  const _OrganisationRow({required this.organisation, this.owner});

  Future<void> _certify(BuildContext context, bool certified) async {
    final o = organisation;
    final ok = await adminConfirm(context,
        title: certified ? 'Certifier ${o.name} ?' : 'Retirer la certification de ${o.name} ?',
        message: certified
            ? "L'organisation recevra le badge vérifié sur ses événements et votes et pourra demander des retraits."
            : "Le badge vérifié disparaît et l'organisation ne pourra plus demander de retrait.",
        confirmLabel: certified ? 'Certifier' : 'Retirer',
        color: certified ? AdminColors.success : AdminColors.danger);
    if (!ok || !context.mounted) return;
    await runAdminAction(context, () => AdminService.instance.setCertified(o, certified),
        success: certified ? '${o.name} est certifiée.' : 'Certification retirée.');
  }

  Future<void> _rejectRequest(BuildContext context) async {
    final ok = await adminConfirm(context,
        title: 'Refuser la demande de ${organisation.name} ?',
        message: "L'organisation reste non certifiée et pourra refaire une demande.",
        confirmLabel: 'Refuser');
    if (!ok || !context.mounted) return;
    await runAdminAction(context, () => AdminService.instance.rejectCertification(organisation),
        success: 'Demande refusée.');
  }

  Future<void> _block(BuildContext context) async {
    final o = organisation;
    if (o.blocked) {
      final ok = await adminConfirm(context,
          title: 'Débloquer ${o.name} ?',
          message: 'Ses événements et votes réapparaissent et elle peut à nouveau publier et retirer.',
          confirmLabel: 'Débloquer',
          color: AdminColors.success);
      if (!ok || !context.mounted) return;
      await runAdminAction(context, () => AdminService.instance.setOrganisationBlocked(o, false),
          success: '${o.name} débloquée.');
      return;
    }
    final reason = await adminPrompt(context,
        title: 'Bloquer ${o.name}',
        message: 'Ses événements et votes sont masqués du public ; elle ne peut plus publier ni retirer.',
        fieldLabel: 'Motif (visible par l\'organisateur)',
        confirmLabel: 'Bloquer',
        color: AdminColors.danger);
    if (reason == null || !context.mounted) return;
    await runAdminAction(context, () => AdminService.instance.setOrganisationBlocked(o, true, reason: reason),
        success: '${o.name} bloquée.');
  }

  Future<void> _delete(BuildContext context) async {
    final o = organisation;
    final ok = await adminConfirm(context,
        title: 'Supprimer ${o.name} ?',
        message: "L'organisation, tous ses événements et toutes ses campagnes de vote seront supprimés "
            'définitivement. Les commandes et retraits restent dans l\'historique.',
        confirmLabel: 'Supprimer définitivement');
    if (!ok || !context.mounted) return;
    await runAdminAction(context, () => AdminService.instance.deleteOrganisation(o), success: '${o.name} supprimée.');
  }

  @override
  Widget build(BuildContext context) {
    final o = organisation;
    final requested = o.certificationRequested && !o.certified;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          AdminAvatar(label: o.name, imageUrl: o.logoUrl, radius: 22),
          const SizedBox(width: 14),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(o.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: adminText(14.5, weight: FontWeight.w700)),
                    ),
                    if (o.certified) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, size: 17, color: AdminColors.info),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (o.certified) const AdminChip(label: 'Certifiée', color: AdminColors.success, icon: Icons.verified_outlined),
                    if (requested)
                      AdminChip(
                        label: o.certificationRequestedAt != null
                            ? 'Certification demandée le ${adminDate.format(o.certificationRequestedAt!)}'
                            : 'Certification demandée',
                        color: AdminColors.warning,
                        icon: Icons.hourglass_top_rounded,
                      ),
                    if (o.blocked) const AdminChip(label: 'Bloquée', color: AdminColors.danger, icon: Icons.block),
                  ],
                ),
                if (o.blocked && o.blockedReason?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text('Motif : ${o.blockedReason}', style: adminText(12, color: AdminColors.danger)),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(owner?.displayName ?? 'Propriétaire inconnu', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: adminText(13, weight: FontWeight.w600)),
                Text(owner?.email ?? o.ownerId, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: adminText(12, color: AdminColors.muted)),
                Text(
                  '${o.followerCount} abonné(s)${o.createdAt != null ? ' · créée le ${adminDate.format(o.createdAt!)}' : ''}',
                  style: adminText(12, color: AdminColors.muted),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (requested) ...[
                AdminActionButton(
                    label: 'Certifier', icon: Icons.verified_outlined, color: AdminColors.success, filled: true,
                    onPressed: () => _certify(context, true)),
                AdminActionButton(label: 'Refuser', icon: Icons.close_rounded, onPressed: () => _rejectRequest(context)),
              ] else if (o.certified)
                AdminActionButton(label: 'Retirer certif.', icon: Icons.remove_moderator_outlined,
                    onPressed: () => _certify(context, false))
              else
                AdminActionButton(label: 'Certifier', icon: Icons.verified_outlined, color: AdminColors.success,
                    onPressed: () => _certify(context, true)),
              AdminActionButton(
                label: o.blocked ? 'Débloquer' : 'Bloquer',
                icon: o.blocked ? Icons.lock_open_rounded : Icons.block,
                color: o.blocked ? AdminColors.success : AdminColors.warning,
                onPressed: () => _block(context),
              ),
              IconButton(
                tooltip: 'Supprimer',
                onPressed: () => _delete(context),
                icon: const Icon(Icons.delete_outline, color: AdminColors.danger),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
