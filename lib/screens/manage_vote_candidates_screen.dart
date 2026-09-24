import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../models/vote_campaign.dart';
import '../models/vote_candidate.dart';
import '../models/vote_category.dart';
import '../services/ai_service.dart';
import '../services/vote_service.dart';
import '../widgets/ai_generate_button.dart';
import '../widgets/auth_widgets.dart'
    show authPrimary, authInk, authMuted, authBorder, showAuthSnack;

/// Gestion des candidats d'une catégorie de vote. Accessible depuis la
/// liste des catégories d'une campagne.
class ManageVoteCandidatesScreen extends StatelessWidget {
  final VoteCampaign campaign;
  final VoteCategory category;

  const ManageVoteCandidatesScreen({super.key, required this.campaign, required this.category});

  void _openForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CandidateForm(campaignId: campaign.id, categoryId: category.id),
    );
  }

  Future<void> _delete(BuildContext context, VoteCandidate candidate) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce candidat ?'),
        content: Text('« ${candidate.name} » sera définitivement supprimé.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await VoteService.instance.deleteCandidate(campaign.id, category.id, candidate.id);
    } catch (_) {
      if (context.mounted) showAuthSnack(context, 'Échec de la suppression.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: authInk,
        title: Text(category.title, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: authInk)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        backgroundColor: authPrimary,
        icon: const Icon(Icons.person_add_alt_1_outlined, color: Colors.white),
        label: Text('Candidat', style: GoogleFonts.nunito(fontWeight: FontWeight.w600, color: Colors.white)),
      ),
      body: SafeArea(
        child: StreamBuilder<List<VoteCandidate>>(
          stream: VoteService.instance.watchCandidates(campaign.id, category.id),
          builder: (context, snapshot) {
            final candidates = snapshot.data ?? const <VoteCandidate>[];
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: authPrimary));
            }
            if (candidates.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('Aucun candidat. Ajoutez-en un avec le bouton ci-dessous.',
                      textAlign: TextAlign.center, style: GoogleFonts.nunito(fontSize: 13, color: authMuted)),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              itemCount: candidates.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _CandidateTile(
                candidate: candidates[i],
                onDelete: () => _delete(context, candidates[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  final VoteCandidate candidate;
  final VoidCallback onDelete;

  const _CandidateTile({required this.candidate, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: authBorder), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFFF4F4F6),
                backgroundImage: candidate.photoUrl != null ? NetworkImage(candidate.photoUrl!) : null,
                child: candidate.photoUrl == null ? const Icon(Icons.person_outline, color: authMuted) : null,
              ),
              Positioned(
                bottom: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: authInk, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white, width: 1.5)),
                  child: Text('N°${candidate.number}', style: GoogleFonts.nunito(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(candidate.name, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: authInk)),
                if (candidate.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(candidate.description, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(fontSize: 12, color: authMuted)),
                ],
                if (candidate.bio.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(candidate.bio, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(fontSize: 11.5, color: authMuted)),
                ],
                const SizedBox(height: 4),
                Text('${candidate.voteCount} vote${candidate.voteCount > 1 ? 's' : ''}',
                    style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: authPrimary)),
              ],
            ),
          ),
          IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, size: 18, color: authMuted)),
        ],
      ),
    );
  }
}

class _CandidateForm extends StatefulWidget {
  final String campaignId;
  final String categoryId;

  const _CandidateForm({required this.campaignId, required this.categoryId});

  @override
  State<_CandidateForm> createState() => _CandidateFormState();
}

class _CandidateFormState extends State<_CandidateForm> {
  final _picker = ImagePicker();
  final _nameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  File? _photo;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _photo = File(picked.path));
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showAuthSnack(context, 'Le nom du candidat est requis.');
      return;
    }
    if (_photo == null) {
      showAuthSnack(context, 'Ajoutez une photo du candidat.');
      return;
    }
    setState(() => _saving = true);
    try {
      await VoteService.instance.addCandidate(
        campaignId: widget.campaignId,
        categoryId: widget.categoryId,
        name: name,
        description: _descriptionCtrl.text,
        bio: _bioCtrl.text,
        photoFile: _photo!,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showAuthSnack(context, e is StateError ? e.message : 'Échec de l\'enregistrement.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nouveau candidat', style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w700, color: authInk)),
          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                width: 120,
                height: 150,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4F6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: authBorder),
                  // Aperçu entier (non rogné), comme l'affichage public.
                  image: _photo != null ? DecorationImage(image: FileImage(_photo!), fit: BoxFit.contain) : null,
                ),
                child: _photo == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_a_photo_outlined, color: authMuted),
                          const SizedBox(height: 6),
                          Text('Photo\n(obligatoire)',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.nunito(fontSize: 11, color: authMuted)),
                        ],
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nom du candidat')),
          const SizedBox(height: 12),
          TextField(controller: _descriptionCtrl, decoration: const InputDecoration(labelText: 'Description courte (ex. Étudiante, 22 ans)')),
          const SizedBox(height: 12),
          TextField(controller: _bioCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Bio (optionnel)')),
          Align(
            alignment: Alignment.centerRight,
            child: AiGenerateButton(
              controller: _bioCtrl,
              validate: () => _nameCtrl.text.trim().isEmpty ? "Renseignez d'abord le nom du candidat." : null,
              generate: (instructions) => AiService.instance.generateCandidateBio(
                name: _nameCtrl.text.trim(),
                shortDescription: _descriptionCtrl.text,
                existing: _bioCtrl.text,
                instructions: instructions,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: authPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                  : Text('Ajouter le candidat', style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
