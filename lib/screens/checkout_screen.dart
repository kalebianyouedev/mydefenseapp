import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/event.dart';
import '../models/order.dart';
import '../models/payment_method.dart';
import '../models/promo_code.dart';
import '../services/event_service.dart';
import '../services/order_service.dart';
import '../widgets/auth_widgets.dart' show authPrimary, authInk, authMuted, authBorder, showAuthSnack;
import 'order_confirmation_screen.dart';

/// Récapitulatif de commande, code promo optionnel, choix Orange Money /
/// MTN Mobile Money et numéro de téléphone. Aucune passerelle réelle
/// n'est connectée : "Payer" crée la commande puis ouvre l'écran de
/// confirmation, où le paiement est validé manuellement (voir
/// [OrderConfirmationScreen]).
class CheckoutScreen extends StatefulWidget {
  final Event event;
  final List<OrderItem> items;

  const CheckoutScreen({super.key, required this.event, required this.items});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  PaymentMethod _method = PaymentMethod.orangeMoney;
  final _phoneCtrl = TextEditingController();
  final _promoCtrl = TextEditingController();

  PromoCode? _appliedPromo;
  bool _checkingPromo = false;
  bool _submitting = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _promoCtrl.dispose();
    super.dispose();
  }

  num get _subtotal => widget.items.fold<num>(0, (sum, i) => sum + i.subtotal);

  num get _discount => _appliedPromo == null ? 0 : _subtotal * _appliedPromo!.percentOff / 100;

  num get _total => _subtotal - _discount;

  Future<void> _applyPromo() async {
    final code = _promoCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() => _checkingPromo = true);
    try {
      final promo = await EventService.instance.validatePromoCode(widget.event.id, code);
      setState(() => _appliedPromo = promo);
      if (!mounted) return;
      showAuthSnack(context, promo == null ? 'Code promo invalide ou épuisé.' : 'Code appliqué : -${promo.percentOff}%.');
    } finally {
      if (mounted) setState(() => _checkingPromo = false);
    }
  }

  Future<void> _pay() async {
    if (_phoneCtrl.text.trim().length < 8) {
      showAuthSnack(context, 'Entrez un numéro de téléphone valide.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final orderId = await OrderService.instance.createOrder(
        event: widget.event,
        items: widget.items,
        paymentMethod: _method,
        paymentPhone: _phoneCtrl.text.trim(),
        promoCode: _appliedPromo?.code,
        totalAmount: _total,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => OrderConfirmationScreen(orderId: orderId)),
      );
    } catch (e) {
      if (mounted) showAuthSnack(context, 'Échec de la création de la commande.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern('fr_FR');
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: authInk,
        title: Text('Paiement', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: authInk)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  Text('Récapitulatif', style: GoogleFonts.nunito(fontSize: 13.5, fontWeight: FontWeight.w700, color: authInk)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(border: Border.all(color: authBorder), borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        Text(widget.event.title, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: authInk)),
                        const SizedBox(height: 10),
                        for (final item in widget.items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text('${item.quantity} × ${item.ticketTypeName}',
                                      style: GoogleFonts.nunito(fontSize: 13, color: authInk)),
                                ),
                                Text('${fmt.format(item.subtotal)} XAF', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: authInk)),
                              ],
                            ),
                          ),
                        const Divider(color: authBorder, height: 20),
                        if (_appliedPromo != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Expanded(child: Text('Réduction (${_appliedPromo!.code})', style: GoogleFonts.nunito(fontSize: 13, color: const Color(0xFF1E9E6B)))),
                                Text('-${fmt.format(_discount)} XAF', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E9E6B))),
                              ],
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(child: Text('Total', style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: authInk))),
                            Text('${fmt.format(_total)} XAF', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: authPrimary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Code promo', style: GoogleFonts.nunito(fontSize: 13.5, fontWeight: FontWeight.w700, color: authInk)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _promoCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            hintText: 'Code promo (optionnel)',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: authBorder)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: authBorder)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: authPrimary, width: 1.4)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _checkingPromo ? null : _applyPromo,
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: authBorder), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
                          child: _checkingPromo
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text('Appliquer', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: authInk)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Moyen de paiement', style: GoogleFonts.nunito(fontSize: 13.5, fontWeight: FontWeight.w700, color: authInk)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _PaymentMethodCard(
                        label: 'Orange Money',
                        color: const Color(0xFFFF7900),
                        selected: _method == PaymentMethod.orangeMoney,
                        onTap: () => setState(() => _method = PaymentMethod.orangeMoney),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _PaymentMethodCard(
                        label: 'MTN MoMo',
                        color: const Color(0xFFFFCC00),
                        selected: _method == PaymentMethod.mtnMomo,
                        onTap: () => setState(() => _method = PaymentMethod.mtnMomo),
                      )),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Numéro ${paymentMethodLabel(_method)}', style: GoogleFonts.nunito(fontSize: 13.5, fontWeight: FontWeight.w700, color: authInk)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: GoogleFonts.nunito(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Ex. 6XX XX XX XX',
                      hintStyle: GoogleFonts.nunito(fontSize: 13.5, color: authMuted),
                      prefixIcon: const Icon(Icons.phone_outlined, size: 20, color: authMuted),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: authBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: authBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: authPrimary, width: 1.4)),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: authBorder))),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _pay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: authPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _submitting
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : Text('Payer ${fmt.format(_total)} XAF', style: GoogleFonts.nunito(fontSize: 15.5, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentMethodCard({required this.label, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.10) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? color : authBorder, width: selected ? 1.6 : 1),
        ),
        child: Column(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: const Icon(Icons.phone_iphone, size: 17, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w700, color: authInk)),
          ],
        ),
      ),
    );
  }
}
