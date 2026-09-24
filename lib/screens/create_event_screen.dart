import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/event.dart';
import '../models/event_category.dart';
import '../models/organisation.dart';
import '../services/ai_service.dart';
import '../services/event_service.dart';
import '../widgets/ai_generate_button.dart';
import '../services/stockimg_client.dart';
import '../widgets/auth_widgets.dart'
    show authPrimary, authInk, authMuted, authBorder, showAuthSnack;

String _describeSaveError(Object e) {
  if (e is StateError) return e.message;
  if (e is StockImgException) return e.message;
  return 'Échec de l\'enregistrement : $e';
}

const _stepLabels = ['Informations', 'Dates', 'Visuels', 'Options'];
const _stepHints = [
  'Le titre, la description et le lieu que le public verra.',
  'Une séance par jour. Vous ajouterez les billets ensuite.',
  'Une couverture donne envie de cliquer. Le reste est facultatif.',
  'Derniers réglages avant de créer l\'événement en brouillon.',
];

/// Mutable draft of a [Seance] while the wizard is open (before it is
/// turned into an immutable [Seance] on submit).
class _SeanceDraft {
  final String id;
  final TextEditingController nameCtrl = TextEditingController();
  DateTime? start;
  DateTime? end;
  DateTime? salesEnd;

  _SeanceDraft(this.id);

  void dispose() => nameCtrl.dispose();
}

/// Assistant de création d'événement en 4 étapes (Informations, Dates,
/// Visuels, Options), adapté mobile de la maquette web. Crée
/// l'événement en brouillon ; les types de billets se configurent
/// ensuite depuis le tableau de bord de l'événement.
class CreateEventScreen extends StatefulWidget {
  final Organisation organisation;

  /// Si renseigné, l'assistant s'ouvre en mode édition (champs
  /// pré-remplis) et met à jour cet événement au lieu d'en créer un.
  final Event? existing;

  const CreateEventScreen({super.key, required this.organisation, this.existing});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _picker = ImagePicker();

  int _step = 0;
  bool _saving = false;

  // Step 1
  late final _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
  late final _descriptionCtrl = TextEditingController(text: widget.existing?.description ?? '');
  late final _venueCtrl = TextEditingController(text: widget.existing?.venue ?? '');
  late final _cityCtrl = TextEditingController(text: widget.existing?.city ?? '');
  late EventCategory? _category = widget.existing?.category;

  // Step 2
  late final List<_SeanceDraft> _seances = widget.existing == null || widget.existing!.seances.isEmpty
      ? [_SeanceDraft('s0')]
      : widget.existing!.seances.map((s) {
          final draft = _SeanceDraft(s.id);
          draft.nameCtrl.text = s.name ?? '';
          draft.start = s.start;
          draft.end = s.end;
          draft.salesEnd = s.salesEnd;
          return draft;
        }).toList();
  int _seanceCounter = 1;

  // Step 3
  File? _coverImage;
  late final _videoUrlCtrl = TextEditingController(text: widget.existing?.videoUrl ?? '');
  final List<File> _gallery = [];

  // Step 4
  late bool _isFree = widget.existing?.isFree ?? false;
  late final _capacityCtrl = TextEditingController(text: widget.existing?.capacity?.toString() ?? '');
  late final _refundPolicyCtrl = TextEditingController(text: widget.existing?.refundPolicy ?? '');

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _venueCtrl.dispose();
    _cityCtrl.dispose();
    _videoUrlCtrl.dispose();
    _capacityCtrl.dispose();
    _refundPolicyCtrl.dispose();
    for (final s in _seances) {
      s.dispose();
    }
    super.dispose();
  }

  bool _validateStep(int step) {
    switch (step) {
      case 0:
        if (_titleCtrl.text.trim().isEmpty) {
          showAuthSnack(context, 'Le titre est requis.');
          return false;
        }
        if (_category == null) {
          showAuthSnack(context, 'Choisissez une catégorie pour l\'événement.');
          return false;
        }
        return true;
      case 1:
        for (final s in _seances) {
          if (s.start == null || s.end == null) {
            showAuthSnack(context, 'Renseignez le début et la fin de chaque séance.');
            return false;
          }
          if (s.end!.isBefore(s.start!)) {
            showAuthSnack(context, 'La fin d\'une séance doit être après son début.');
            return false;
          }
        }
        return true;
      default:
        return true;
    }
  }

  void _next() {
    if (!_validateStep(_step)) return;
    if (_step < 3) {
      setState(() => _step += 1);
    } else {
      _submit();
    }
  }

  void _previous() {
    if (_step == 0) {
      Navigator.of(context).pop();
    } else {
      setState(() => _step -= 1);
    }
  }

  Future<void> _pickCover() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _coverImage = File(picked.path));
  }

  Future<void> _addGalleryImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _gallery.add(File(picked.path)));
  }

  void _addSeance() {
    setState(() => _seances.add(_SeanceDraft('s${_seanceCounter++}')));
  }

  void _removeSeance(_SeanceDraft s) {
    if (_seances.length == 1) return;
    setState(() {
      _seances.remove(s);
      s.dispose();
    });
  }

  Future<void> _submit() async {
    if (!_validateStep(0) || !_validateStep(1)) return;
    setState(() => _saving = true);
    try {
      final seances = _seances
          .map((s) => Seance(
                id: s.id,
                name: s.nameCtrl.text,
                start: s.start!,
                end: s.end!,
                salesEnd: s.salesEnd,
              ))
          .toList();
      final existing = widget.existing;
      if (existing == null) {
        final eventId = await EventService.instance.createDraft(
          organisation: widget.organisation,
          title: _titleCtrl.text,
          description: _descriptionCtrl.text,
          venue: _venueCtrl.text,
          city: _cityCtrl.text,
          category: _category!,
          coverImageFile: _coverImage,
          videoUrl: _videoUrlCtrl.text,
          galleryFiles: _gallery,
          seances: seances,
          isFree: _isFree,
          capacity: int.tryParse(_capacityCtrl.text.trim()),
          refundPolicy: _refundPolicyCtrl.text,
        );
        if (!mounted) return;
        showAuthSnack(context, 'Événement créé en brouillon.');
        Navigator.of(context).pop(eventId);
      } else {
        await EventService.instance.updateDetails(
          eventId: existing.id,
          title: _titleCtrl.text,
          description: _descriptionCtrl.text,
          venue: _venueCtrl.text,
          city: _cityCtrl.text,
          category: _category!,
          newCoverImageFile: _coverImage,
          coverImageUrl: existing.coverImageUrl,
          videoUrl: _videoUrlCtrl.text,
          seances: seances,
          isFree: _isFree,
          capacity: int.tryParse(_capacityCtrl.text.trim()),
          refundPolicy: _refundPolicyCtrl.text,
        );
        if (!mounted) return;
        showAuthSnack(context, 'Événement mis à jour.');
        Navigator.of(context).pop(existing.id);
      }
    } catch (e) {
      if (mounted) {
        showAuthSnack(context, _describeSaveError(e));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              step: _step,
              isEdit: widget.existing != null,
              onClose: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: IndexedStack(
                  index: _step,
                  sizing: StackFit.loose,
                  children: [
                    _InformationsStep(
                      titleCtrl: _titleCtrl,
                      descriptionCtrl: _descriptionCtrl,
                      venueCtrl: _venueCtrl,
                      cityCtrl: _cityCtrl,
                      category: _category,
                      onCategoryChanged: (c) => setState(() => _category = c),
                    ),
                    _DatesStep(
                      seances: _seances,
                      onAdd: _addSeance,
                      onRemove: _removeSeance,
                      onChanged: () => setState(() {}),
                    ),
                    _VisuelsStep(
                      cover: _coverImage,
                      onPickCover: _pickCover,
                      onClearCover: () => setState(() => _coverImage = null),
                      videoUrlCtrl: _videoUrlCtrl,
                      gallery: _gallery,
                      onAddGalleryImage: _addGalleryImage,
                      onRemoveGalleryImage: (f) => setState(() => _gallery.remove(f)),
                    ),
                    _OptionsStep(
                      isFree: _isFree,
                      onFreeChanged: (v) => setState(() => _isFree = v),
                      capacityCtrl: _capacityCtrl,
                      refundPolicyCtrl: _refundPolicyCtrl,
                    ),
                  ],
                ),
              ),
            ),
            _BottomBar(
              step: _step,
              saving: _saving,
              isEdit: widget.existing != null,
              onPrevious: _previous,
              onNext: _next,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int step;
  final bool isEdit;
  final VoidCallback onClose;

  const _Header({required this.step, required this.isEdit, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isEdit ? 'Modifier l\'événement' : 'Nouvel événement',
                  style: GoogleFonts.nunito(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: authInk,
                  ),
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, color: authMuted),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _stepHints[step],
            style: GoogleFonts.nunito(fontSize: 12.5, color: authMuted),
          ),
          const SizedBox(height: 18),
          Row(
            children: List.generate(_stepLabels.length, (i) {
              final active = i == step;
              final done = i < step;
              return Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done
                            ? const Color(0xFF1E9E6B)
                            : active
                                ? authInk
                                : const Color(0xFFE3E3E8),
                      ),
                      child: done
                          ? const Icon(Icons.check, size: 15, color: Colors.white)
                          : Text(
                              '${i + 1}',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: active ? Colors.white : authMuted,
                              ),
                            ),
                    ),
                    if (i < _stepLabels.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          color: done ? const Color(0xFF1E9E6B) : authBorder,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            'Étape ${step + 1} sur 4 : ${_stepLabels[step]}',
            style: GoogleFonts.nunito(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: authInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int step;
  final bool saving;
  final bool isEdit;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _BottomBar({
    required this.step,
    required this.saving,
    required this.isEdit,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: authBorder)),
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: saving ? null : onPrevious,
            icon: Icon(step == 0 ? Icons.close : Icons.arrow_back, size: 18, color: authInk),
            label: Text(
              step == 0 ? 'Annuler' : 'Précédent',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w600, color: authInk),
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: saving ? null : onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: authPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : Text(
                      step == 3 ? (isEdit ? 'Enregistrer' : 'Créer l\'événement') : 'Continuer',
                      style: GoogleFonts.nunito(fontSize: 14.5, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.title,
    this.trailing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: authBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: authPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: authInk,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

Widget _fieldLabel(String label) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: authInk),
      ),
    );

InputDecoration _fieldDecoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.nunito(fontSize: 13.5, color: authMuted),
      filled: true,
      fillColor: const Color(0xFFF7F8FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: authBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: authBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: authPrimary, width: 1.4),
      ),
    );

// ---------------------------------------------------------------------
// Step 1 — Informations
// ---------------------------------------------------------------------

class _InformationsStep extends StatelessWidget {
  final TextEditingController titleCtrl;
  final TextEditingController descriptionCtrl;
  final TextEditingController venueCtrl;
  final TextEditingController cityCtrl;
  final EventCategory? category;
  final ValueChanged<EventCategory> onCategoryChanged;

  const _InformationsStep({
    required this.titleCtrl,
    required this.descriptionCtrl,
    required this.venueCtrl,
    required this.cityCtrl,
    required this.category,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.info_outline,
      title: 'INFORMATIONS',
      children: [
        _fieldLabel('Titre'),
        TextField(controller: titleCtrl, style: GoogleFonts.nunito(fontSize: 14), decoration: _fieldDecoration('Festival Urbain de Douala')),
        const SizedBox(height: 16),
        _fieldLabel('Catégorie'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in EventCategory.values)
              ChoiceChip(
                selected: category == c,
                onSelected: (_) => onCategoryChanged(c),
                showCheckmark: false,
                avatar: Icon(c.icon, size: 16, color: category == c ? Colors.white : authInk),
                label: Text(c.label),
                labelStyle: GoogleFonts.nunito(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: category == c ? Colors.white : authInk,
                ),
                selectedColor: authPrimary,
                backgroundColor: Colors.white,
                side: BorderSide(color: category == c ? authPrimary : authBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _fieldLabel('Description')),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: AiGenerateButton(
                controller: descriptionCtrl,
                validate: () => titleCtrl.text.trim().isEmpty ? "Renseignez d'abord le titre de l'événement." : null,
                generate: (instructions) => AiService.instance.generateEventDescription(
                  title: titleCtrl.text.trim(),
                  venue: venueCtrl.text,
                  city: cityCtrl.text,
                  existing: descriptionCtrl.text,
                  instructions: instructions,
                ),
              ),
            ),
          ],
        ),
        TextField(
          controller: descriptionCtrl,
          maxLines: 5,
          style: GoogleFonts.nunito(fontSize: 14),
          decoration: _fieldDecoration('Décrivez l\'événement pour le public...'),
        ),
        const SizedBox(height: 16),
        _fieldLabel('Lieu'),
        TextField(controller: venueCtrl, style: GoogleFonts.nunito(fontSize: 14), decoration: _fieldDecoration('Palais des Congrès')),
        const SizedBox(height: 16),
        _fieldLabel('Ville'),
        TextField(controller: cityCtrl, style: GoogleFonts.nunito(fontSize: 14), decoration: _fieldDecoration('Yaoundé')),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Step 2 — Dates
// ---------------------------------------------------------------------

class _DatesStep extends StatelessWidget {
  final List<_SeanceDraft> seances;
  final VoidCallback onAdd;
  final ValueChanged<_SeanceDraft> onRemove;
  final VoidCallback onChanged;

  const _DatesStep({
    required this.seances,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
  });

  Future<void> _pickDateTime(BuildContext context, DateTime? initial, ValueChanged<DateTime> onPicked) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? now.add(const Duration(days: 1)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 3),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: initial != null ? TimeOfDay.fromDateTime(initial) : const TimeOfDay(hour: 19, minute: 0),
    );
    if (time == null) return;
    onPicked(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'DATES & SÉANCES',
              style: GoogleFonts.nunito(fontSize: 11.5, fontWeight: FontWeight.w700, color: authInk, letterSpacing: 0.6),
            ),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 16, color: authPrimary),
              label: Text('Ajouter une date', style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w600, color: authPrimary)),
            ),
          ],
        ),
        Text(
          'Chaque séance aura ses propres types de billets, configurables après la création de l\'événement.',
          style: GoogleFonts.nunito(fontSize: 12, color: authMuted),
        ),
        for (var i = 0; i < seances.length; i++)
          _SeanceCard(
            index: i,
            draft: seances[i],
            onRemove: seances.length > 1 ? () => onRemove(seances[i]) : null,
            onPickStart: () => _pickDateTime(context, seances[i].start, (d) {
              seances[i].start = d;
              onChanged();
            }),
            onPickEnd: () => _pickDateTime(context, seances[i].end, (d) {
              seances[i].end = d;
              onChanged();
            }),
            onPickSalesEnd: () => _pickDateTime(context, seances[i].salesEnd, (d) {
              seances[i].salesEnd = d;
              onChanged();
            }),
          ),
      ],
    );
  }
}

class _SeanceCard extends StatelessWidget {
  final int index;
  final _SeanceDraft draft;
  final VoidCallback? onRemove;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback onPickSalesEnd;

  const _SeanceCard({
    required this.index,
    required this.draft,
    required this.onRemove,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onPickSalesEnd,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM y • HH:mm', 'fr_FR');
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: authBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SÉANCE ${index + 1}',
                style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: authMuted, letterSpacing: 0.6),
              ),
              if (onRemove != null)
                GestureDetector(
                  onTap: onRemove,
                  child: const Icon(Icons.delete_outline, size: 18, color: authMuted),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _fieldLabel('Nom de la séance (optionnel)'),
          TextField(
            controller: draft.nameCtrl,
            style: GoogleFonts.nunito(fontSize: 14),
            decoration: _fieldDecoration('Jour 1, Soirée VIP...'),
          ),
          const SizedBox(height: 14),
          _fieldLabel('Début'),
          _DateTimeField(value: draft.start, formatter: fmt, onTap: onPickStart),
          const SizedBox(height: 14),
          _fieldLabel('Fin'),
          _DateTimeField(value: draft.end, formatter: fmt, onTap: onPickEnd),
          const SizedBox(height: 14),
          _fieldLabel('Fin des ventes (optionnel)'),
          _DateTimeField(value: draft.salesEnd, formatter: fmt, onTap: onPickSalesEnd),
        ],
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  final DateTime? value;
  final DateFormat formatter;
  final VoidCallback onTap;

  const _DateTimeField({required this.value, required this.formatter, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: authBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 16, color: authMuted),
            const SizedBox(width: 10),
            Text(
              value == null ? 'Sélectionner date et heure' : formatter.format(value!),
              style: GoogleFonts.nunito(fontSize: 13.5, color: value == null ? authMuted : authInk),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Step 3 — Visuels
// ---------------------------------------------------------------------

class _VisuelsStep extends StatelessWidget {
  final File? cover;
  final VoidCallback onPickCover;
  final VoidCallback onClearCover;
  final TextEditingController videoUrlCtrl;
  final List<File> gallery;
  final VoidCallback onAddGalleryImage;
  final ValueChanged<File> onRemoveGalleryImage;

  const _VisuelsStep({
    required this.cover,
    required this.onPickCover,
    required this.onClearCover,
    required this.videoUrlCtrl,
    required this.gallery,
    required this.onAddGalleryImage,
    required this.onRemoveGalleryImage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          icon: Icons.image_outlined,
          title: 'COUVERTURE & VIDÉO',
          children: [
            _fieldLabel('Image de couverture'),
            GestureDetector(
              onTap: onPickCover,
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: authBorder, style: BorderStyle.solid),
                ),
                clipBehavior: Clip.antiAlias,
                child: cover == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_photo_alternate_outlined, size: 30, color: authMuted),
                            const SizedBox(height: 8),
                            Text('Cliquer pour choisir une image', style: GoogleFonts.nunito(fontSize: 12.5, color: authMuted)),
                            Text('JPG, PNG ou WebP, 5 Mo max', style: GoogleFonts.nunito(fontSize: 11, color: authMuted)),
                          ],
                        ),
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(cover!, fit: BoxFit.cover),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: onClearCover,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), shape: BoxShape.circle),
                                child: const Icon(Icons.close, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            _fieldLabel('Vidéo (URL)'),
            TextField(
              controller: videoUrlCtrl,
              style: GoogleFonts.nunito(fontSize: 14),
              decoration: _fieldDecoration('YouTube, Vimeo...'),
            ),
          ],
        ),
        _SectionCard(
          icon: Icons.collections_outlined,
          title: 'GALERIE (OPTIONNEL)',
          trailing: TextButton.icon(
            onPressed: onAddGalleryImage,
            icon: const Icon(Icons.add, size: 15, color: authPrimary),
            label: Text('Image', style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: authPrimary)),
          ),
          children: [
            Text('Jusqu\'à 20 médias.', style: GoogleFonts.nunito(fontSize: 12, color: authMuted)),
            if (gallery.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: gallery.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final file = gallery[i];
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(file, width: 84, height: 84, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => onRemoveGalleryImage(file),
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 13, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Step 4 — Options
// ---------------------------------------------------------------------

class _OptionsStep extends StatelessWidget {
  final bool isFree;
  final ValueChanged<bool> onFreeChanged;
  final TextEditingController capacityCtrl;
  final TextEditingController refundPolicyCtrl;

  const _OptionsStep({
    required this.isFree,
    required this.onFreeChanged,
    required this.capacityCtrl,
    required this.refundPolicyCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.tune,
      title: 'OPTIONS',
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Événement gratuit', style: GoogleFonts.nunito(fontSize: 13.5, fontWeight: FontWeight.w600, color: authInk)),
                    const SizedBox(height: 2),
                    Text(
                      isFree
                          ? 'Aucun paiement ne sera demandé au public.'
                          : 'Vous configurerez les prix des billets après la création.',
                      style: GoogleFonts.nunito(fontSize: 11.5, color: authMuted),
                    ),
                  ],
                ),
              ),
              Switch(value: isFree, activeThumbColor: authPrimary, onChanged: onFreeChanged),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _fieldLabel('Capacité (optionnel)'),
        TextField(
          controller: capacityCtrl,
          keyboardType: TextInputType.number,
          style: GoogleFonts.nunito(fontSize: 14),
          decoration: _fieldDecoration('Nombre de places maximum'),
        ),
        const SizedBox(height: 16),
        _fieldLabel('Politique de remboursement (optionnel)'),
        TextField(
          controller: refundPolicyCtrl,
          maxLines: 3,
          style: GoogleFonts.nunito(fontSize: 14),
          decoration: _fieldDecoration('Ex. remboursable jusqu\'à 48h avant l\'événement.'),
        ),
      ],
    );
  }
}
