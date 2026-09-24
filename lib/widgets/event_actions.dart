import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/event.dart';
import '../models/payment_method.dart';
import '../services/event_service.dart';
import '../services/organisation_service.dart';
import 'auth_widgets.dart' show authPrimary, authInk, authMuted, authBorder, showAuthSnack;

const _boostColor = Color(0xFFF5A300);

/// Cœur « J'aime » d'un événement, avec le nombre de j'aime. [light]
/// l'adapte à un fond sombre (sur l'affiche).
class EventLikeButton extends StatelessWidget {
  final Event event;
  final bool light;

  const EventLikeButton({super.key, required this.event, this.light = false});

  Future<void> _toggle(BuildContext context) async {
    try {
      await EventService.instance.toggleLike(event);
    } catch (_) {
      if (context.mounted) showAuthSnack(context, "Impossible d'enregistrer le j'aime.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: EventService.instance.watchLiked(event.id),
      builder: (context, snap) {
        final liked = snap.data ?? false;
        final baseColor = light ? Colors.white : authInk;
        return Material(
          color: light ? Colors.black.withValues(alpha: 0.45) : Colors.white,
          shape: StadiumBorder(side: BorderSide(color: light ? Colors.transparent : authBorder)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => _toggle(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(liked ? Icons.favorite : Icons.favorite_border,
                      size: 18, color: liked ? const Color(0xFFE53950) : baseColor),
                  if (event.likeCount > 0) ...[
                    const SizedBox(width: 4),
                    Text('${event.likeCount}',
                        style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: baseColor)),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Petit bouton éclair ⚡ qui ouvre le paiement d'un boost (100 F min.).
class EventBoostButton extends StatelessWidget {
  final Event event;

  const EventBoostButton({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Booster cet événement',
      child: Material(
        color: _boostColor.withValues(alpha: 0.14),
        shape: const StadiumBorder(side: BorderSide(color: _boostColor)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => showBoostSheet(context, event),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt, size: 18, color: _boostColor),
                if (event.boosts > 0) ...[
                  const SizedBox(width: 2),
                  Text('${event.boosts}',
                      style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: authInk)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showBoostSheet(BuildContext context, Event event) async {
  final boosted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _BoostSheet(event: event),
  );
  if (boosted == true && context.mounted) {
    showAuthSnack(context, '⚡ Merci ! « ${event.title} » est boosté.');
  }
}

class _BoostSheet extends StatefulWidget {
  final Event event;

  const _BoostSheet({required this.event});

  @override
  State<_BoostSheet> createState() => _BoostSheetState();
}

class _BoostSheetState extends State<_BoostSheet> {
  static const _presets = [100, 500, 1000, 2000, 5000];

  final _amountCtrl = TextEditingController(text: '${EventService.minBoostAmount}');
  final _phoneCtrl = TextEditingController();
  PaymentMethod _method = PaymentMethod.orangeMoney;
  bool _submitting = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  int get _amount => int.tryParse(_amountCtrl.text.replaceAll(RegExp(r'\s'), '')) ?? 0;

  Future<void> _pay() async {
    if (_amount < EventService.minBoostAmount) {
      showAuthSnack(context, 'Le boost minimum est de ${EventService.minBoostAmount} F CFA.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await EventService.instance.boost(
        event: widget.event,
        amount: _amount,
        paymentMethod: _method,
        paymentPhone: _phoneCtrl.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showAuthSnack(context, e is StateError ? e.message : 'Échec du boost.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _decoration(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.nunito(fontSize: 13.5, color: authMuted),
        prefixIcon: Icon(icon, size: 20, color: authMuted),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: authBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: authBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: _boostColor, width: 1.4)),
      );

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern('fr_FR');
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: _boostColor.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.bolt, color: _boostColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Booster l\'événement',
                      style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w700, color: authInk)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Plus un événement est boosté, plus il remonte en haut de l\'accueil. '
              'À partir de ${EventService.minBoostAmount} F CFA.',
              style: GoogleFonts.nunito(fontSize: 12.5, color: authMuted),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in _presets)
                  ChoiceChip(
                    selected: _amount == p,
                    onSelected: (_) => setState(() => _amountCtrl.text = '$p'),
                    showCheckmark: false,
                    label: Text('${fmt.format(p)} F'),
                    labelStyle: GoogleFonts.nunito(
                        fontSize: 12.5, fontWeight: FontWeight.w600, color: _amount == p ? Colors.white : authInk),
                    selectedColor: _boostColor,
                    backgroundColor: Colors.white,
                    side: BorderSide(color: _amount == p ? _boostColor : authBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.nunito(fontSize: 14),
              decoration: _decoration('Montant (F CFA)', Icons.payments_outlined),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MethodChip(
                    label: 'Orange Money',
                    color: const Color(0xFFFF7900),
                    selected: _method == PaymentMethod.orangeMoney,
                    onTap: () => setState(() => _method = PaymentMethod.orangeMoney),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MethodChip(
                    label: 'MTN MoMo',
                    color: const Color(0xFFFFCC00),
                    selected: _method == PaymentMethod.mtnMomo,
                    onTap: () => setState(() => _method = PaymentMethod.mtnMomo),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              style: GoogleFonts.nunito(fontSize: 14),
              decoration: _decoration('Numéro ${paymentMethodLabel(_method)}', Icons.phone_outlined),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _pay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _boostColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                    : const Icon(Icons.bolt),
                label: Text(
                  'Booster pour ${fmt.format(_amount < 0 ? 0 : _amount)} F CFA',
                  style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _MethodChip({required this.label, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.10) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : authBorder, width: selected ? 1.6 : 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: const Icon(Icons.phone_iphone, size: 12, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w700, color: authInk)),
          ],
        ),
      ),
    );
  }
}

/// Bouton « S'abonner » / « Abonné » à une organisation.
class FollowOrganisationButton extends StatelessWidget {
  final String organisationId;
  final String organisationName;
  final String? organisationLogoUrl;

  const FollowOrganisationButton({
    super.key,
    required this.organisationId,
    required this.organisationName,
    this.organisationLogoUrl,
  });

  Future<void> _toggle(BuildContext context, bool following) async {
    try {
      await OrganisationService.instance.toggleFollow(
        organisationId: organisationId,
        organisationName: organisationName,
        organisationLogoUrl: organisationLogoUrl,
      );
      if (context.mounted) {
        showAuthSnack(context, following ? 'Désabonné de $organisationName.' : 'Abonné à $organisationName.');
      }
    } catch (_) {
      if (context.mounted) showAuthSnack(context, "Impossible de modifier l'abonnement.");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (organisationId.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<bool>(
      stream: OrganisationService.instance.watchFollowing(organisationId),
      builder: (context, snap) {
        final following = snap.data ?? false;
        return SizedBox(
          height: 34,
          child: following
              ? OutlinedButton(
                  onPressed: () => _toggle(context, true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: authInk,
                    side: const BorderSide(color: authBorder),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: const StadiumBorder(),
                  ),
                  child: Text('Abonné', style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w600)),
                )
              : ElevatedButton(
                  onPressed: () => _toggle(context, false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: authPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: const StadiumBorder(),
                  ),
                  child: Text("S'abonner", style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
        );
      },
    );
  }
}
