import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../widgets/auth_widgets.dart'
    show authPrimary, authInk, authMuted, authBorder, showAuthSnack;

/// Page "Mon profil" : photo, bannière, et informations personnelles,
/// enregistrées dans Firestore (`users/{uid}`) avec les images sur
/// Firebase Storage.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();

  DateTime? _birthDate;
  String? _photoUrl;
  String? _bannerUrl;
  File? _photoFile;
  File? _bannerFile;

  bool _loading = true;
  bool _saving = false;

  User? get _user => AuthService.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    _companyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final uid = _user?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final profile = await ProfileService.instance.fetchProfile(uid);
      if (!mounted) return;
      if (profile != null) {
        _firstNameCtrl.text = profile.firstName;
        _lastNameCtrl.text = profile.lastName;
        _phoneCtrl.text = profile.phone;
        _cityCtrl.text = profile.city;
        _addressCtrl.text = profile.address;
        _companyCtrl.text = profile.companyName;
        _birthDate = profile.birthDate;
        _photoUrl = profile.photoUrl;
        _bannerUrl = profile.bannerUrl;
      } else {
        final displayName = _user?.displayName ?? '';
        final parts = displayName.trim().split(' ');
        if (parts.isNotEmpty && parts.first.isNotEmpty) {
          _firstNameCtrl.text = parts.first;
          if (parts.length > 1) {
            _lastNameCtrl.text = parts.sublist(1).join(' ');
          }
        }
      }
    } catch (_) {
      if (mounted) {
        showAuthSnack(
          context,
          "Impossible de charger le profil (vérifiez votre connexion).",
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage({required bool isBanner}) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: isBanner ? 1600 : 800,
    );
    if (picked == null) return;
    setState(() {
      if (isBanner) {
        _bannerFile = File(picked.path);
      } else {
        _photoFile = File(picked.path);
      }
    });
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 20),
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: authPrimary,
                  onPrimary: Colors.white,
                  onSurface: authInk,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _save() async {
    final uid = _user?.uid;
    if (uid == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      String? photoUrl = _photoUrl;
      String? bannerUrl = _bannerUrl;

      if (_photoFile != null) {
        photoUrl = await ProfileService.instance.uploadImage(
          uid: uid,
          file: _photoFile!,
          isBanner: false,
        );
      }
      if (_bannerFile != null) {
        bannerUrl = await ProfileService.instance.uploadImage(
          uid: uid,
          file: _bannerFile!,
          isBanner: true,
        );
      }

      final profile = UserProfile(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        birthDate: _birthDate,
        companyName: _companyCtrl.text.trim(),
        photoUrl: photoUrl,
        bannerUrl: bannerUrl,
      );

      await ProfileService.instance.saveProfile(uid, profile);

      final fullName = profile.fullName;
      if (fullName.isNotEmpty && _user?.displayName != fullName) {
        await _user?.updateDisplayName(fullName);
      }

      if (!mounted) return;
      showAuthSnack(context, 'Profil enregistré avec succès.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      showAuthSnack(context, "Erreur lors de l'enregistrement du profil.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: authPrimary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 44, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text(
                    'Informations personnelles',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: authInk,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          controller: _firstNameCtrl,
                          label: 'Prénom',
                          icon: Icons.badge_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          controller: _lastNameCtrl,
                          label: 'Nom',
                          icon: Icons.badge_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _phoneCtrl,
                    label: 'Téléphone',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),
                  _birthDateField(),
                  const SizedBox(height: 14),
                  _field(
                    controller: _cityCtrl,
                    label: 'Ville',
                    icon: Icons.location_city_outlined,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _addressCtrl,
                    label: 'Adresse',
                    icon: Icons.home_outlined,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Entreprise',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: authInk,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _field(
                    controller: _companyCtrl,
                    label: "Nom de l'entreprise",
                    icon: Icons.apartment_outlined,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
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
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.save_outlined,
                                    size: 20, color: Colors.white),
                                const SizedBox(width: 10),
                                Text(
                                  'Enregistrer',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SizedBox(
      height: 230,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Bannière
          GestureDetector(
            onTap: () => _pickImage(isBanner: true),
            child: Container(
              height: 168,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F2A6B), Color(0xFFE30B4C)],
                ),
                image: _bannerFile != null
                    ? DecorationImage(
                        image: FileImage(_bannerFile!), fit: BoxFit.cover)
                    : (imageProviderFromPath(_bannerUrl) != null
                        ? DecorationImage(
                            image: imageProviderFromPath(_bannerUrl)!,
                            fit: BoxFit.cover)
                        : null),
              ),
            ),
          ),
          // Bouton retour
          Positioned(
            top: 8,
            left: 8,
            child: SafeArea(
              bottom: false,
              child: _circleIconButton(
                icon: Icons.arrow_back,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          // Bouton changer bannière
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(
              bottom: false,
              child: _circleIconButton(
                icon: Icons.camera_alt_outlined,
                onTap: () => _pickImage(isBanner: true),
              ),
            ),
          ),
          // Avatar
          Positioned(
            left: 20,
            top: 128,
            child: GestureDetector(
              onTap: () => _pickImage(isBanner: false),
              child: Container(
                width: 96,
                height: 96,
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: authPrimary.withOpacity(0.12),
                      backgroundImage: _photoFile != null
                          ? FileImage(_photoFile!) as ImageProvider
                          : imageProviderFromPath(_photoUrl),
                      child: (_photoFile == null &&
                              imageProviderFromPath(_photoUrl) == null)
                          ? Text(
                              _initials(),
                              style: GoogleFonts.poppins(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: authPrimary,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: authPrimary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 128,
            top: 178,
            right: 20,
            child: Text(
              'Mon profil',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: authInk,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleIconButton(
      {required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }

  String _initials() {
    final f = _firstNameCtrl.text.trim();
    final l = _lastNameCtrl.text.trim();
    if (f.isEmpty && l.isEmpty) {
      final email = _user?.email ?? '';
      return email.isNotEmpty ? email[0].toUpperCase() : '?';
    }
    final a = f.isNotEmpty ? f[0] : '';
    final b = l.isNotEmpty ? l[0] : '';
    return (a + b).toUpperCase();
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(fontSize: 14, color: authInk),
      cursorColor: authPrimary,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(fontSize: 13.5, color: authMuted),
        prefixIcon: Icon(icon, size: 20, color: authMuted),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
    );
  }

  Widget _birthDateField() {
    final formatted = _birthDate != null
        ? DateFormat('dd/MM/yyyy').format(_birthDate!)
        : '';
    return GestureDetector(
      onTap: _pickBirthDate,
      child: AbsorbPointer(
        child: TextFormField(
          controller: TextEditingController(text: formatted),
          style: GoogleFonts.poppins(fontSize: 14, color: authInk),
          decoration: InputDecoration(
            labelText: 'Date de naissance',
            labelStyle: GoogleFonts.poppins(fontSize: 13.5, color: authMuted),
            prefixIcon: const Icon(Icons.cake_outlined,
                size: 20, color: authMuted),
            suffixIcon: const Icon(Icons.calendar_today_outlined,
                size: 18, color: authMuted),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
      ),
    );
  }
}
