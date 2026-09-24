import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth_widgets.dart'
    show authPrimary, authInk, authMuted, authBorder, showAuthSnack;

/// Petit bouton « Générer avec l'IA » placé au-dessus d'un champ texte.
/// Il ouvre une fenêtre où l'organisateur écrit ses consignes (ton, infos
/// à mentionner, format caption Instagram…), puis appelle [generate] avec
/// ces consignes et remplace le contenu de [controller] par le résultat.
/// [validate] peut renvoyer un message d'erreur (ex. nom requis) pour
/// bloquer la génération.
class AiGenerateButton extends StatefulWidget {
  final TextEditingController controller;
  final Future<String> Function(String instructions) generate;
  final String? Function()? validate;

  const AiGenerateButton({
    super.key,
    required this.controller,
    required this.generate,
    this.validate,
  });

  @override
  State<AiGenerateButton> createState() => _AiGenerateButtonState();
}

class _AiGenerateButtonState extends State<AiGenerateButton> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _run() async {
    final error = widget.validate?.call();
    if (error != null) {
      showAuthSnack(context, error);
      return;
    }
    final instructions = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) =>
          _InstructionsSheet(improving: widget.controller.text.trim().isNotEmpty),
    );
    if (instructions == null || !mounted) return; // fenêtre fermée
    setState(() => _loading = true);
    try {
      final text = await widget.generate(instructions);
      widget.controller.text = text;
    } catch (e) {
      debugPrint('Génération IA : $e');
      if (mounted) {
        showAuthSnack(
          context,
          e is StateError
              ? e.message
              : kDebugMode
                  ? "L'IA est indisponible : $e"
                  : "L'IA est indisponible pour le moment.",
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.trim().isNotEmpty;
    return TextButton.icon(
      onPressed: _loading ? null : _run,
      style: TextButton.styleFrom(
        foregroundColor: authPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
      ),
      icon: _loading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: authPrimary),
            )
          : const Icon(Icons.auto_awesome, size: 16),
      label: Text(
        _loading
            ? 'Rédaction…'
            : hasText
                ? "Améliorer avec l'IA"
                : "Générer avec l'IA",
        style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Fenêtre de consignes : l'organisateur écrit ce qu'il veut (facultatif).
/// Renvoie les consignes (éventuellement vides) ou null si fermée.
class _InstructionsSheet extends StatefulWidget {
  final bool improving;

  const _InstructionsSheet({required this.improving});

  @override
  State<_InstructionsSheet> createState() => _InstructionsSheetState();
}

class _InstructionsSheetState extends State<_InstructionsSheet> {
  static const _examples = [
    'Ton festif avec des emojis',
    'Format caption Instagram avec hashtags',
    'Court et professionnel',
    'En anglais',
  ];

  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _addExample(String example) {
    final current = _ctrl.text.trim();
    _ctrl.text = current.isEmpty ? example : '$current. $example';
    _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 18, color: authPrimary),
              const SizedBox(width: 8),
              Text(
                widget.improving ? "Améliorer avec l'IA" : "Générer avec l'IA",
                style: GoogleFonts.nunito(
                    fontSize: 17, fontWeight: FontWeight.w700, color: authInk),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Dites à l'IA ce que vous voulez : ton, informations à mettre en "
            'avant, format réseaux sociaux… (facultatif)',
            style: GoogleFonts.nunito(fontSize: 12.5, color: authMuted),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            style: GoogleFonts.nunito(fontSize: 14, color: authInk),
            decoration: InputDecoration(
              hintText:
                  'Ex : mentionne le dress code tout en blanc et le DJ invité',
              hintStyle: GoogleFonts.nunito(fontSize: 13, color: authMuted),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: authBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: authBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: authPrimary, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final example in _examples)
                ActionChip(
                  label: Text(example,
                      style: GoogleFonts.nunito(fontSize: 12, color: authInk)),
                  backgroundColor: const Color(0xFFF4F4F6),
                  side: BorderSide.none,
                  onPressed: () => _addExample(example),
                ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: authPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: Text(widget.improving ? 'Améliorer' : 'Générer',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
