import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/event.dart';
import '../models/promo_code.dart';
import '../services/event_service.dart';
import '../widgets/auth_widgets.dart'
    show authPrimary, authInk, authMuted, authBorder, showAuthSnack;

/// Codes promo d'un événement (réduction en % appliquée au checkout).
/// Accessible depuis le tableau de bord de l'événement, bouton "Codes
/// promo".
class ManagePromoCodesScreen extends StatelessWidget {
  final Event event;

  const ManagePromoCodesScreen({super.key, required this.event});

  Future<void> _addCode(BuildContext context) async {
    final codeCtrl = TextEditingController();
    final percentCtrl = TextEditingController();
    final maxUsesCtrl = TextEditingController();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nouveau code promo', style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w700, color: authInk)),
            const SizedBox(height: 16),
            TextField(
              controller: codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Code (ex. VIP20)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: percentCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Réduction (%)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: maxUsesCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Utilisations max (vide = illimité)'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  final percent = int.tryParse(percentCtrl.text.trim());
                  if (codeCtrl.text.trim().isEmpty || percent == null) {
                    showAuthSnack(sheetContext, 'Renseignez un code et un pourcentage valides.');
                    return;
                  }
                  try {
                    await EventService.instance.addPromoCode(
                      eventId: event.id,
                      code: codeCtrl.text,
                      percentOff: percent.clamp(1, 100),
                      maxUses: maxUsesCtrl.text.trim().isEmpty ? null : int.tryParse(maxUsesCtrl.text.trim()),
                    );
                    if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                  } catch (e) {
                    if (sheetContext.mounted) {
                      showAuthSnack(sheetContext, e is StateError ? e.message : 'Échec de l\'enregistrement.');
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: authPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Créer', style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
    if (saved == true && context.mounted) {
      showAuthSnack(context, 'Code promo créé.');
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
        title: Text('Codes promo', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: authInk)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addCode(context),
        backgroundColor: authPrimary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: StreamBuilder<List<PromoCode>>(
          stream: EventService.instance.watchPromoCodes(event.id),
          builder: (context, snapshot) {
            final codes = snapshot.data ?? const <PromoCode>[];
            if (codes.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Aucun code promo. Créez-en un pour offrir une réduction au checkout.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(fontSize: 13.5, color: authMuted),
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              itemCount: codes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final promo = codes[i];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(border: Border.all(color: authBorder), borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(promo.code, style: GoogleFonts.nunito(fontSize: 14.5, fontWeight: FontWeight.w700, color: authInk)),
                            const SizedBox(height: 3),
                            Text(
                              '-${promo.percentOff}% · ${promo.maxUses == null ? '${promo.usedCount} utilisations' : '${promo.usedCount}/${promo.maxUses} utilisations'}',
                              style: GoogleFonts.nunito(fontSize: 12, color: authMuted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => EventService.instance.deletePromoCode(event.id, promo.code),
                        icon: const Icon(Icons.delete_outline, size: 18, color: authMuted),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
