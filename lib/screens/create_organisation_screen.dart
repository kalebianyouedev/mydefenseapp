import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../services/ai_service.dart';
import '../services/organisation_service.dart';
import '../widgets/ai_generate_button.dart';
import '../widgets/auth_widgets.dart'
    show authPrimary, authInk, authMuted, authBorder, showAuthSnack;

/// Formulaire de création d'une organisation (nom, description, logo
/// optionnel). Renvoie l'organisation créée via `Navigator.pop`.
class CreateOrganisationScreen extends StatefulWidget {
  const CreateOrganisationScreen({super.key});

  @override
  State<CreateOrganisationScreen> createState() =>
      _CreateOrganisationScreenState();
}

class _CreateOrganisationScreenState extends State<CreateOrganisationScreen> {
  final _nameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _picker = ImagePicker();

  File? _logoFile;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _logoFile = File(picked.path));
  }

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty) {
      showAuthSnack(context, 'Le nom de l\'organisation est requis.');
      return;
    }
    setState(() => _saving = true);
    try {
      final organisation = await OrganisationService.instance.create(
        name: _nameCtrl.text,
        description: _descriptionCtrl.text,
        logoFile: _logoFile,
      );
      if (!mounted) return;
      Navigator.of(context).pop(organisation);
    } catch (_) {
      if (mounted) {
        showAuthSnack(context, "Échec de la création. Réessayez.");
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
        title: Text(
          'Nouvelle organisation',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: authInk,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickLogo,
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F4F6),
                      shape: BoxShape.circle,
                      image: _logoFile != null
                          ? DecorationImage(
                              image: FileImage(_logoFile!), fit: BoxFit.cover)
                          : null,
                    ),
                    child: _logoFile == null
                        ? const Icon(Icons.add_a_photo_outlined,
                            color: authMuted, size: 26)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Logo (optionnel)',
                  style: GoogleFonts.poppins(fontSize: 12.5, color: authMuted),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Nom de l\'organisation',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: authInk,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                style: GoogleFonts.poppins(fontSize: 14, color: authInk),
                decoration: InputDecoration(
                  hintText: 'Ex : Afro Nights Events',
                  hintStyle: GoogleFonts.poppins(fontSize: 14, color: authMuted),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
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
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Description (optionnel)',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: authInk,
                      ),
                    ),
                  ),
                  AiGenerateButton(
                    controller: _descriptionCtrl,
                    validate: () => _nameCtrl.text.trim().isEmpty
                        ? "Renseignez d'abord le nom de l'organisation."
                        : null,
                    generate: (instructions) => AiService.instance
                        .generateOrganisationDescription(
                      name: _nameCtrl.text.trim(),
                      existing: _descriptionCtrl.text,
                      instructions: instructions,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _descriptionCtrl,
                minLines: 3,
                maxLines: 5,
                style: GoogleFonts.poppins(fontSize: 14, color: authInk),
                decoration: InputDecoration(
                  hintText: 'Décrivez votre structure en quelques mots...',
                  hintStyle: GoogleFonts.poppins(fontSize: 14, color: authMuted),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
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
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _saving ? null : _create,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: authPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Créer l\'organisation',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
