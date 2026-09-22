import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/event.dart';
import '../models/ticket_type.dart';
import '../services/event_service.dart';
import '../widgets/auth_widgets.dart'
    show authPrimary, authInk, authMuted, authBorder, showAuthSnack;

/// Gestion des types de billets d'un événement (une séance = ses propres
/// types). Accessible depuis le tableau de bord de l'événement, bouton
/// "Billets".
class ManageTicketTypesScreen extends StatelessWidget {
  final Event event;

  const ManageTicketTypesScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: authInk,
        title: Text('Types de billets',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: authInk)),
      ),
      body: SafeArea(
        child: StreamBuilder<List<TicketType>>(
          stream: EventService.instance.watchTicketTypes(event.id),
          builder: (context, snapshot) {
            final types = snapshot.data ?? const <TicketType>[];
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              children: [
                for (final seance in event.seances) ...[
                  Text(
                    seance.name ?? DateFormat('d MMM y • HH:mm', 'fr_FR').format(seance.start),
                    style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w700, color: authInk),
                  ),
                  const SizedBox(height: 10),
                  ...types.where((t) => t.seanceId == seance.id).map(
                        (t) => _TicketTypeCard(
                          type: t,
                          onEdit: () => _openForm(context, seance: seance, existing: t),
                          onDelete: () => _delete(context, t),
                        ),
                      ),
                  OutlinedButton.icon(
                    onPressed: () => _openForm(context, seance: seance),
                    icon: const Icon(Icons.add, size: 16, color: authPrimary),
                    label: Text('Ajouter un type de billet',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: authPrimary)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: authBorder),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, TicketType type) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce type de billet ?'),
        content: Text('« ${type.name} » sera définitivement supprimé.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await EventService.instance.deleteTicketType(event.id, type.id);
    } catch (_) {
      if (context.mounted) showAuthSnack(context, 'Échec de la suppression.');
    }
  }

  void _openForm(BuildContext context, {required Seance seance, TicketType? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _TicketTypeForm(event: event, seance: seance, existing: existing),
    );
  }
}

class _TicketTypeCard extends StatelessWidget {
  final TicketType type;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TicketTypeCard({required this.type, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern('fr_FR');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: authBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type.name, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: authInk)),
                const SizedBox(height: 3),
                Text(
                  '${fmt.format(type.price)} XAF · ${type.quantityTotal == null ? 'Illimité' : '${type.remaining} / ${type.quantityTotal} restants'}',
                  style: GoogleFonts.poppins(fontSize: 12, color: authMuted),
                ),
              ],
            ),
          ),
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 18, color: authMuted)),
          IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, size: 18, color: authMuted)),
        ],
      ),
    );
  }
}

class _TicketTypeForm extends StatefulWidget {
  final Event event;
  final Seance seance;
  final TicketType? existing;

  const _TicketTypeForm({required this.event, required this.seance, this.existing});

  @override
  State<_TicketTypeForm> createState() => _TicketTypeFormState();
}

class _TicketTypeFormState extends State<_TicketTypeForm> {
  late final _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
  late final _priceCtrl = TextEditingController(text: widget.existing?.price.toString() ?? '');
  late final _quantityCtrl =
      TextEditingController(text: widget.existing?.quantityTotal?.toString() ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _quantityCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final price = num.tryParse(_priceCtrl.text.trim().replaceAll(',', '.'));
    if (name.isEmpty || price == null) {
      showAuthSnack(context, 'Renseignez un nom et un prix valides.');
      return;
    }
    final quantity = _quantityCtrl.text.trim().isEmpty ? null : int.tryParse(_quantityCtrl.text.trim());
    setState(() => _saving = true);
    try {
      if (widget.existing == null) {
        await EventService.instance.addTicketType(
          eventId: widget.event.id,
          seanceId: widget.seance.id,
          name: name,
          price: price,
          quantityTotal: quantity,
        );
      } else {
        await EventService.instance.updateTicketType(
          eventId: widget.event.id,
          ticketTypeId: widget.existing!.id,
          name: name,
          price: price,
          quantityTotal: quantity,
        );
      }
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
          Text(
            widget.existing == null ? 'Nouveau type de billet' : 'Modifier le type de billet',
            style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: authInk),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Nom (ex. Standard, VIP)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Prix (XAF)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _quantityCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Quantité disponible (vide = illimité)'),
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
                  : Text('Enregistrer', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
