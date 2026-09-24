import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/organisation.dart';
import '../services/ai_service.dart';
import '../services/vote_service.dart';
import '../widgets/ai_generate_button.dart';
import '../widgets/auth_widgets.dart'
    show authPrimary, authInk, authMuted, authBorder, showAuthSnack;

/// Formulaire de création d'une campagne de vote (titre, description,
/// couverture, dates d'ouverture/clôture). Les catégories et candidats
/// se configurent ensuite depuis le tableau de bord de la campagne.
class CreateVoteCampaignScreen extends StatefulWidget {
  final Organisation organisation;

  const CreateVoteCampaignScreen({super.key, required this.organisation});

  @override
  State<CreateVoteCampaignScreen> createState() => _CreateVoteCampaignScreenState();
}

class _CreateVoteCampaignScreenState extends State<CreateVoteCampaignScreen> {
  final _picker = ImagePicker();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  File? _coverImage;
  DateTime? _startsAt;
  DateTime? _endsAt;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _coverImage = File(picked.path));
  }

  Future<void> _pickDateTime(DateTime? initial, ValueChanged<DateTime> onPicked) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 3),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: initial != null ? TimeOfDay.fromDateTime(initial) : const TimeOfDay(hour: 20, minute: 0),
    );
    if (time == null) return;
    onPicked(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _create() async {
    if (_titleCtrl.text.trim().isEmpty) {
      showAuthSnack(context, 'Le titre de la campagne est requis.');
      return;
    }
    if (_coverImage == null) {
      showAuthSnack(context, 'Ajoutez une image de couverture pour la campagne.');
      return;
    }
    if (_startsAt != null && _endsAt != null && _endsAt!.isBefore(_startsAt!)) {
      showAuthSnack(context, 'La clôture doit être après l\'ouverture.');
      return;
    }
    setState(() => _saving = true);
    try {
      final campaignId = await VoteService.instance.createCampaign(
        organisation: widget.organisation,
        title: _titleCtrl.text,
        description: _descriptionCtrl.text,
        coverImageFile: _coverImage!,
        startsAt: _startsAt,
        endsAt: _endsAt,
      );
      if (!mounted) return;
      Navigator.of(context).pop(campaignId);
    } catch (e) {
      if (mounted) {
        showAuthSnack(context, e is StateError ? e.message : 'Échec de la création.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM y • HH:mm', 'fr_FR');
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: authInk,
        title: Text('Nouvelle campagne de vote',
            style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: authInk)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            GestureDetector(
              onTap: _pickCover,
              child: Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4F6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: authBorder),
                  // Aperçu entier (non rogné), comme l'affichage public.
                  image: _coverImage != null
                      ? DecorationImage(image: FileImage(_coverImage!), fit: BoxFit.contain)
                      : null,
                ),
                child: _coverImage == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.emoji_events_outlined, size: 34, color: authMuted),
                            const SizedBox(height: 8),
                            Text('Image de couverture (obligatoire)',
                                style: GoogleFonts.nunito(fontSize: 13, color: authMuted)),
                          ],
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 22),
            Text('Titre de la campagne', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: authInk)),
            const SizedBox(height: 8),
            TextField(
              controller: _titleCtrl,
              style: GoogleFonts.nunito(fontSize: 14, color: authInk),
              decoration: InputDecoration(
                hintText: 'Ex : Meilleur artiste camerounais 2026',
                hintStyle: GoogleFonts.nunito(fontSize: 13.5, color: authMuted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: authBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: authBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: authPrimary, width: 1.4)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text('Description (optionnel)',
                      style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: authInk)),
                ),
                AiGenerateButton(
                  controller: _descriptionCtrl,
                  validate: () => _titleCtrl.text.trim().isEmpty ? "Renseignez d'abord le titre de la campagne." : null,
                  generate: (instructions) => AiService.instance.generateVoteCampaignDescription(
                    title: _titleCtrl.text.trim(),
                    organisationName: widget.organisation.name,
                    existing: _descriptionCtrl.text,
                    instructions: instructions,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionCtrl,
              minLines: 3,
              maxLines: 5,
              style: GoogleFonts.nunito(fontSize: 14, color: authInk),
              decoration: InputDecoration(
                hintText: 'Décrivez le contexte, les règles, les critères...',
                hintStyle: GoogleFonts.nunito(fontSize: 13.5, color: authMuted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: authBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: authBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: authPrimary, width: 1.4)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'Ouverture',
                    value: _startsAt == null ? null : dateFmt.format(_startsAt!),
                    onTap: () => _pickDateTime(_startsAt, (d) => setState(() => _startsAt = d)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateField(
                    label: 'Clôture',
                    value: _endsAt == null ? null : dateFmt.format(_endsAt!),
                    onTap: () => _pickDateTime(_endsAt, (d) => setState(() => _endsAt = d)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _saving ? null : _create,
                style: ElevatedButton.styleFrom(
                  backgroundColor: authPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : Text('Créer la campagne', style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _DateField({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: authBorder)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 14, color: authMuted),
                const SizedBox(width: 6),
                Text(label, style: GoogleFonts.nunito(fontSize: 11.5, color: authMuted)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value ?? 'Choisir',
              style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: value == null ? authMuted : authInk),
            ),
          ],
        ),
      ),
    );
  }
}
