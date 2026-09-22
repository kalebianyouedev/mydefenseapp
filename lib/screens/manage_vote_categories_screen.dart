import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/vote_campaign.dart';
import '../models/vote_candidate.dart';
import '../models/vote_category.dart';
import '../services/vote_service.dart';
import '../widgets/auth_widgets.dart'
    show authPrimary, authInk, authMuted, authBorder, showAuthSnack;
import 'manage_vote_candidates_screen.dart';

/// Gestion des catégories d'une campagne de vote (chacune a son propre
/// prix par vote). Accessible depuis le tableau de bord de la campagne,
/// bouton "Catégories".
class ManageVoteCategoriesScreen extends StatelessWidget {
  final VoteCampaign campaign;

  const ManageVoteCategoriesScreen({super.key, required this.campaign});

  void _openForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CategoryForm(campaignId: campaign.id),
    );
  }

  Future<void> _delete(BuildContext context, VoteCategory category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer cette catégorie ?'),
        content: Text('« ${category.title} » et ses candidats seront supprimés.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await VoteService.instance.deleteCategory(campaign.id, category.id);
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
        title: Text('Catégories', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: authInk)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        backgroundColor: authPrimary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Ajouter', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
      ),
      body: SafeArea(
        child: StreamBuilder<List<VoteCategory>>(
          stream: VoteService.instance.watchCategories(campaign.id),
          builder: (context, snapshot) {
            final categories = snapshot.data ?? const <VoteCategory>[];
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: authPrimary));
            }
            if (categories.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('Aucune catégorie. Ajoutez-en une avec le bouton ci-dessous.',
                      textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 13, color: authMuted)),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _CategoryTile(
                campaign: campaign,
                category: categories[i],
                onDelete: () => _delete(context, categories[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final VoteCampaign campaign;
  final VoteCategory category;
  final VoidCallback onDelete;

  const _CategoryTile({required this.campaign, required this.category, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern('fr_FR');
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ManageVoteCandidatesScreen(campaign: campaign, category: category)),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: authBorder), borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F4F6),
                    image: category.imageUrl != null
                        ? DecorationImage(image: NetworkImage(category.imageUrl!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: category.imageUrl == null
                      ? const Icon(Icons.category_outlined, color: authMuted)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(category.title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: authInk)),
                    const SizedBox(height: 3),
                    Text('${fmt.format(category.pricePerVote)} XAF / vote',
                        style: GoogleFonts.poppins(fontSize: 12, color: authMuted)),
                    const SizedBox(height: 4),
                    StreamBuilder<List<VoteCandidate>>(
                      stream: VoteService.instance.watchCandidates(campaign.id, category.id),
                      builder: (context, snap) {
                        final count = snap.data?.length ?? 0;
                        return Text('$count candidat${count > 1 ? 's' : ''}',
                            style: GoogleFonts.poppins(fontSize: 11.5, color: authPrimary, fontWeight: FontWeight.w600));
                      },
                    ),
                  ],
                ),
              ),
              IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, size: 18, color: authMuted)),
              const Icon(Icons.chevron_right, color: authMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryForm extends StatefulWidget {
  final String campaignId;

  const _CategoryForm({required this.campaignId});

  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  final _picker = ImagePicker();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  File? _image;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _image = File(picked.path));
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final price = num.tryParse(_priceCtrl.text.trim().replaceAll(',', '.'));
    if (title.isEmpty || price == null || price <= 0) {
      showAuthSnack(context, 'Renseignez un titre et un prix par vote valides.');
      return;
    }
    setState(() => _saving = true);
    try {
      await VoteService.instance.addCategory(
        campaignId: widget.campaignId,
        title: title,
        description: _descriptionCtrl.text,
        pricePerVote: price,
        imageFile: _image,
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
          Text('Nouvelle catégorie', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: authInk)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F4F6),
                borderRadius: BorderRadius.circular(14),
                image: _image != null ? DecorationImage(image: FileImage(_image!), fit: BoxFit.cover) : null,
              ),
              child: _image == null
                  ? const Center(child: Icon(Icons.add_photo_alternate_outlined, color: authMuted))
                  : null,
            ),
          ),
          const SizedBox(height: 14),
          TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Titre (ex. Meilleur artiste)')),
          const SizedBox(height: 12),
          TextField(controller: _descriptionCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Description (optionnel)')),
          const SizedBox(height: 12),
          TextField(
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Prix par vote (XAF)'),
          ),
          const SizedBox(height: 20),
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
                  : Text('Ajouter la catégorie', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
