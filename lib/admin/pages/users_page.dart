import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../admin_service.dart';
import '../admin_widgets.dart';

enum _Filter { all, active, blocked, admins }

/// Utilisateurs : blocage/déblocage, suppression, droits administrateur.
class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  _Filter _filter = _Filter.all;
  String _query = '';

  bool _test(AdminUser u, _Filter f) => switch (f) {
        _Filter.all => !u.moderation.deleted,
        _Filter.active => !u.moderation.blocked,
        _Filter.blocked => u.moderation.blocked && !u.moderation.deleted,
        _Filter.admins => u.isAdmin,
      };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminUser>>(
      stream: AdminService.instance.watchUsers(),
      builder: (context, snap) {
        final all = snap.data ?? const <AdminUser>[];
        final q = _query.trim().toLowerCase();
        final list = all.where((u) {
          if (!_test(u, _filter)) return false;
          if (q.isEmpty) return true;
          return u.name.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q) ||
              u.phone.contains(q) ||
              u.uid.toLowerCase().contains(q);
        }).toList();
        return ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            AdminPageHeader(
              title: 'Utilisateurs',
              subtitle: 'Tous les comptes de l\'application',
              actions: [AdminSearchField(hint: 'Nom, email, téléphone…', onChanged: (v) => setState(() => _query = v))],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: AdminFilterTabs<_Filter>(
                selected: _filter,
                onSelected: (f) => setState(() => _filter = f),
                tabs: [
                  for (final (f, label) in const [
                    (_Filter.all, 'Tous'),
                    (_Filter.active, 'Actifs'),
                    (_Filter.blocked, 'Bloqués'),
                    (_Filter.admins, 'Administrateurs'),
                  ])
                    (f, label, all.where((u) => _test(u, f)).length),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (snap.hasError)
              AdminError(error: snap.error!)
            else if (!snap.hasData)
              const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator()))
            else if (list.isEmpty)
              const AdminEmpty(icon: Icons.people_outline, text: 'Aucun utilisateur dans cette liste.')
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: AdminCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < list.length; i++) ...[
                        if (i > 0) const Divider(height: 1, color: AdminColors.border),
                        _UserRow(user: list[i]),
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

class _UserRow extends StatelessWidget {
  final AdminUser user;

  const _UserRow({required this.user});

  bool get _isMe => user.uid == AuthService.instance.currentUser?.uid;

  Future<void> _toggleBlock(BuildContext context) async {
    if (user.moderation.blocked) {
      final ok = await adminConfirm(context,
          title: 'Débloquer ${user.displayName} ?',
          message: "L'utilisateur pourra de nouveau se connecter et utiliser l'application.",
          confirmLabel: 'Débloquer',
          color: AdminColors.success);
      if (!ok || !context.mounted) return;
      await runAdminAction(context, () => AdminService.instance.setUserBlocked(user, false),
          success: '${user.displayName} débloqué.');
      return;
    }
    final reason = await adminPrompt(context,
        title: 'Bloquer ${user.displayName}',
        message: "L'utilisateur est déconnecté à son prochain lancement et ne peut plus rien publier, acheter ni retirer.",
        fieldLabel: 'Motif (affiché à l\'utilisateur)',
        confirmLabel: 'Bloquer',
        color: AdminColors.danger,
        required: false);
    if (reason == null || !context.mounted) return;
    await runAdminAction(context, () => AdminService.instance.setUserBlocked(user, true, reason: reason),
        success: '${user.displayName} bloqué.');
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await adminConfirm(context,
        title: 'Supprimer ${user.displayName} ?',
        message: 'Sa fiche est effacée, le compte ne peut plus se connecter et ses organisations sont supprimées '
            "avec leurs événements et votes. (Le compte d'authentification peut ensuite être effacé depuis la console Firebase.)",
        confirmLabel: 'Supprimer définitivement');
    if (!ok || !context.mounted) return;
    await runAdminAction(context, () => AdminService.instance.deleteUser(user), success: '${user.displayName} supprimé.');
  }

  Future<void> _toggleAdmin(BuildContext context) async {
    final grant = !user.isAdmin;
    final ok = await adminConfirm(context,
        title: grant ? 'Donner les droits admin ?' : 'Retirer les droits admin ?',
        message: grant
            ? '${user.displayName} pourra se connecter à cet espace et tout gérer.'
            : "${user.displayName} n'aura plus accès à l'espace administrateur.",
        confirmLabel: grant ? 'Donner les droits' : 'Retirer',
        color: grant ? AdminColors.ink : AdminColors.danger);
    if (!ok || !context.mounted) return;
    await runAdminAction(context, () => AdminService.instance.setAdmin(user, grant),
        success: grant ? 'Droits admin accordés.' : 'Droits admin retirés.');
  }

  @override
  Widget build(BuildContext context) {
    final u = user;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          AdminAvatar(label: u.displayName, imageUrl: u.photoUrl, radius: 20),
          const SizedBox(width: 14),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(u.displayName, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: adminText(14, weight: FontWeight.w700)),
                    ),
                    if (u.isAdmin) ...[
                      const SizedBox(width: 8),
                      const AdminChip(label: 'Admin', color: AdminColors.primary, icon: Icons.shield_outlined),
                    ],
                    if (u.moderation.blocked) ...[
                      const SizedBox(width: 8),
                      const AdminChip(label: 'Bloqué', color: AdminColors.danger, icon: Icons.block),
                    ],
                    if (_isMe) ...[
                      const SizedBox(width: 8),
                      const AdminChip(label: 'Vous', color: AdminColors.info),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                SelectableText(u.email.isNotEmpty ? u.email : u.uid, style: adminText(12.5, color: AdminColors.muted)),
                if (u.moderation.blocked && u.moderation.reason?.isNotEmpty == true)
                  Text('Motif : ${u.moderation.reason}', style: adminText(12, color: AdminColors.danger)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text([u.phone, u.city].where((e) => e.isNotEmpty).join(' · ').ifEmpty('—'),
                    style: adminText(12.5)),
                Text(
                  u.lastSeenAt != null ? 'Vu le ${adminDate.format(u.lastSeenAt!)}' : 'Jamais vu depuis la mise à jour',
                  style: adminText(12, color: AdminColors.muted),
                ),
                if (u.createdAt != null)
                  Text('Inscrit le ${adminDate.format(u.createdAt!)}', style: adminText(12, color: AdminColors.muted)),
              ],
            ),
          ),
          if (!_isMe)
            Wrap(
              spacing: 8,
              children: [
                AdminActionButton(
                  label: u.moderation.blocked ? 'Débloquer' : 'Bloquer',
                  icon: u.moderation.blocked ? Icons.lock_open_rounded : Icons.block,
                  color: u.moderation.blocked ? AdminColors.success : AdminColors.warning,
                  onPressed: () => _toggleBlock(context),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Plus',
                  icon: const Icon(Icons.more_vert, color: AdminColors.muted),
                  onSelected: (v) {
                    if (v == 'admin') _toggleAdmin(context);
                    if (v == 'delete') _delete(context);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'admin',
                      child: Text(u.isAdmin ? 'Retirer les droits admin' : 'Donner les droits admin'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Supprimer le compte', style: TextStyle(color: AdminColors.danger)),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
