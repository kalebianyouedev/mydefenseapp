import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/payment_method.dart';
import '../models/vote_order.dart';
import '../services/vote_service.dart';
import '../widgets/auth_widgets.dart' show authPrimary, authInk, authMuted, showAuthSnack;

/// Suivi d'un achat de votes : tant qu'aucune passerelle Orange Money /
/// MTN Mobile Money réelle n'est branchée, le paiement est confirmé ici
/// à la main. Une fois confirmé, les votes sont comptés pour le
/// candidat.
class VoteOrderConfirmationScreen extends StatefulWidget {
  final String orderId;

  const VoteOrderConfirmationScreen({super.key, required this.orderId});

  @override
  State<VoteOrderConfirmationScreen> createState() => _VoteOrderConfirmationScreenState();
}

class _VoteOrderConfirmationScreenState extends State<VoteOrderConfirmationScreen> {
  bool _confirming = false;

  Future<void> _confirm() async {
    setState(() => _confirming = true);
    try {
      await VoteService.instance.confirmVoteOrder(widget.orderId);
    } catch (e) {
      if (mounted) {
        showAuthSnack(context, e is StateError ? e.message : 'Échec de la confirmation.');
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
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
        title: Text('Votre vote', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: authInk)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: Text('Accueil', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: authMuted)),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<VoteOrder?>(
          stream: VoteService.instance.watchOrder(widget.orderId),
          builder: (context, snapshot) {
            final order = snapshot.data;
            if (order == null) {
              return const Center(child: CircularProgressIndicator(color: authPrimary));
            }
            return order.status == VoteOrderStatus.confirmed
                ? _ConfirmedView(order: order)
                : _PendingView(order: order, confirming: _confirming, onConfirm: _confirm);
          },
        ),
      ),
    );
  }
}

class _PendingView extends StatelessWidget {
  final VoteOrder order;
  final bool confirming;
  final VoidCallback onConfirm;

  const _PendingView({required this.order, required this.confirming, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern('fr_FR');
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(color: authPrimary.withOpacity(0.10), shape: BoxShape.circle),
            child: const Icon(Icons.phone_iphone, size: 40, color: authPrimary),
          ),
          const SizedBox(height: 22),
          Text('Demande de paiement envoyée', textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700, color: authInk)),
          const SizedBox(height: 10),
          Text(
            'Une demande de ${fmt.format(order.totalAmount)} XAF a été envoyée par ${paymentMethodLabel(order.paymentMethod)} au ${order.paymentPhone} '
            'pour ${order.quantity} vote${order.quantity > 1 ? 's' : ''} en faveur de ${order.candidateName}. '
            'Validez-la sur votre téléphone, puis confirmez ci-dessous.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 13.5, color: authMuted, height: 1.5),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: confirming ? null : onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: authPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: confirming
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Text('J\'ai validé le paiement', style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmedView extends StatelessWidget {
  final VoteOrder order;

  const _ConfirmedView({required this.order});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(color: Color(0x1A1E9E6B), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle, size: 46, color: Color(0xFF1E9E6B)),
          ),
          const SizedBox(height: 20),
          Text('Vote confirmé !', style: GoogleFonts.nunito(fontSize: 19, fontWeight: FontWeight.w700, color: authInk)),
          const SizedBox(height: 8),
          Text(
            '${order.quantity} vote${order.quantity > 1 ? 's' : ''} enregistré${order.quantity > 1 ? 's' : ''} pour ${order.candidateName}, '
            'dans la catégorie ${order.categoryTitle}.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 13.5, color: authMuted, height: 1.5),
          ),
          const SizedBox(height: 6),
          Text('Merci d\'avoir participé à « ${order.campaignTitle} ».',
              textAlign: TextAlign.center, style: GoogleFonts.nunito(fontSize: 12.5, color: authMuted)),
        ],
      ),
    );
  }
}
