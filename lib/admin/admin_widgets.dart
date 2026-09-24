import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Palette de l'espace administrateur, aux couleurs de Ça Bouge Où ?
/// (bleu nuit de la marque + rouge du logo).
class AdminColors {
  static const sidebar = Color(0xFF1E3A8A);
  static const sidebarActive = Color(0x29FFFFFF);
  static const sidebarHover = Color(0x14FFFFFF);
  static const background = Color(0xFFF8FAFC);
  static const surface = Colors.white;
  static const border = Color(0xFFE2E8F0);
  static const field = Color(0xFFEAF0FB);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const primary = Color(0xFF1E3A8A);
  static const accent = Color(0xFFE30B4C);
  static const chart = Color(0xFF2F55C9);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFC98A00);
  static const info = Color(0xFF2F55C9);
  static const danger = Color(0xFFDC2626);
}

final adminMoney = NumberFormat.decimalPattern('fr_FR');
final adminDate = DateFormat('d MMM y · HH:mm', 'fr_FR');

String formatXaf(num value) => '${adminMoney.format(value.round())} XAF';

TextStyle adminText(double size, {FontWeight weight = FontWeight.w400, Color color = AdminColors.ink}) =>
    GoogleFonts.nunito(fontSize: size, fontWeight: weight, color: color);

/// Titre de page + sous-titre + actions à droite.
class AdminPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> actions;

  const AdminPageHeader({super.key, required this.title, required this.subtitle, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: adminText(22, weight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(subtitle, style: adminText(13.5, color: AdminColors.muted)),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// Carte blanche à bordure fine.
class AdminCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AdminCard({super.key, required this.child, this.padding = const EdgeInsets.all(20)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border),
      ),
      child: child,
    );
  }
}

class AdminChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const AdminChip({super.key, required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(label, style: adminText(11.5, weight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class AdminSearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const AdminSearchField({super.key, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 42,
      child: TextField(
        onChanged: onChanged,
        style: adminText(13.5),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: adminText(13.5, color: AdminColors.muted),
          prefixIcon: const Icon(Icons.search, size: 19, color: AdminColors.muted),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AdminColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AdminColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AdminColors.primary)),
        ),
      ),
    );
  }
}

/// Filtres sous forme d'onglets pilules (Tous / En attente / ...).
class AdminFilterTabs<T> extends StatelessWidget {
  final List<(T, String, int?)> tabs;
  final T selected;
  final ValueChanged<T> onSelected;

  const AdminFilterTabs({super.key, required this.tabs, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (value, label, count) in tabs)
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => onSelected(value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: value == selected ? AdminColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: value == selected ? AdminColors.primary : AdminColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: adminText(12.5,
                          weight: FontWeight.w600, color: value == selected ? Colors.white : AdminColors.ink)),
                  if (count != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: value == selected ? Colors.white24 : AdminColors.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$count',
                          style: adminText(11, weight: FontWeight.w700, color: value == selected ? Colors.white : AdminColors.muted)),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class AdminAvatar extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final double radius;

  const AdminAvatar({super.key, required this.label, this.imageUrl, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AdminColors.primary.withValues(alpha: 0.10),
      backgroundImage: url != null && url.startsWith('http') ? NetworkImage(url) : null,
      child: url != null && url.startsWith('http')
          ? null
          : Text(label.isEmpty ? '?' : label.substring(0, 1).toUpperCase(),
              style: adminText(radius * 0.8, weight: FontWeight.w700, color: AdminColors.primary)),
    );
  }
}

class AdminEmpty extends StatelessWidget {
  final IconData icon;
  final String text;

  const AdminEmpty({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 40, color: AdminColors.muted),
            const SizedBox(height: 10),
            Text(text, style: adminText(14, color: AdminColors.muted)),
          ],
        ),
      ),
    );
  }
}

class AdminError extends StatelessWidget {
  final Object error;

  const AdminError({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    final denied = error.toString().contains('permission-denied');
    return Padding(
      padding: const EdgeInsets.all(32),
      child: AdminCard(
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AdminColors.danger),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                denied
                    ? "Accès refusé par Firestore : ce compte n'est pas administrateur ou les règles ne sont pas déployées."
                    : 'Erreur de chargement : $error',
                style: adminText(13.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Petit bouton d'action de ligne (icône + texte).
class AdminActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool filled;

  const AdminActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color = AdminColors.ink,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = filled
        ? ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          )
        : OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color.withValues(alpha: 0.35)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          );
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Text(label, style: adminText(12.5, weight: FontWeight.w600, color: filled ? Colors.white : color)),
      ],
    );
    return filled
        ? ElevatedButton(onPressed: onPressed, style: style, child: child)
        : OutlinedButton(onPressed: onPressed, style: style, child: child);
  }
}

// ---------------------------------------------------------------------
// Dialogues
// ---------------------------------------------------------------------

Future<bool> adminConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmer',
  Color color = AdminColors.danger,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: adminText(17, weight: FontWeight.w700)),
      content: SizedBox(width: 420, child: Text(message, style: adminText(13.5, color: AdminColors.muted))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, elevation: 0),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Demande un texte (motif, référence...). Renvoie null si annulé.
Future<String?> adminPrompt(
  BuildContext context, {
  required String title,
  required String message,
  required String fieldLabel,
  String confirmLabel = 'Valider',
  Color color = AdminColors.ink,
  bool required = true,
}) async {
  final ctrl = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: adminText(17, weight: FontWeight.w700)),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: adminText(13.5, color: AdminColors.muted)),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: fieldLabel, border: const OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: required && ctrl.text.trim().isEmpty ? null : () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, elevation: 0),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ),
  );
  ctrl.dispose();
  return result;
}

void adminToast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: adminText(13.5, color: Colors.white)),
      backgroundColor: error ? AdminColors.danger : AdminColors.primary,
      behavior: SnackBarBehavior.floating,
      width: 460,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

/// Exécute une action admin avec retour visuel (succès / erreur).
Future<void> runAdminAction(BuildContext context, Future<void> Function() action, {required String success}) async {
  try {
    await action();
    if (context.mounted) adminToast(context, success);
  } catch (e) {
    if (!context.mounted) return;
    final msg = e is StateError
        ? e.message
        : e.toString().contains('permission-denied')
            ? 'Action refusée par les règles Firestore.'
            : 'Échec : $e';
    adminToast(context, msg, error: true);
  }
}
