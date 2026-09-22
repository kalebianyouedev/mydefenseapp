import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/order.dart';
import '../models/payment_method.dart';
import '../models/ticket.dart';
import '../services/order_service.dart';
import '../services/ticket_pdf_service.dart';
import '../widgets/auth_widgets.dart' show authPrimary, authInk, authMuted, authBorder, showAuthSnack;

/// Suivi d'une commande : tant qu'aucune passerelle Orange Money / MTN
/// Mobile Money réelle n'est branchée, le paiement est confirmé ici à
/// la main (simulateur de l'accusé de réception mobile money). Une fois
/// confirmée, les billets (avec QR code) apparaissent et peuvent être
/// partagés en PDF.
class OrderConfirmationScreen extends StatefulWidget {
  final String orderId;

  const OrderConfirmationScreen({super.key, required this.orderId});

  @override
  State<OrderConfirmationScreen> createState() => _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> {
  bool _confirming = false;
  bool _sharing = false;

  Future<void> _confirmPayment() async {
    setState(() => _confirming = true);
    try {
      await OrderService.instance.confirmOrder(widget.orderId);
    } catch (e) {
      if (mounted) {
        showAuthSnack(context, e is StateError ? e.message : 'Échec de la confirmation.');
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Future<void> _share(TicketOrder order, List<Ticket> tickets) async {
    setState(() => _sharing = true);
    try {
      await TicketPdfService.instance.shareTickets(order: order, tickets: tickets);
    } catch (_) {
      if (mounted) showAuthSnack(context, 'Échec de la génération du PDF.');
    } finally {
      if (mounted) setState(() => _sharing = false);
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
        title: Text('Votre commande', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: authInk)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: Text('Accueil', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: authMuted)),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<TicketOrder?>(
          stream: OrderService.instance.watchOrder(widget.orderId),
          builder: (context, orderSnap) {
            final order = orderSnap.data;
            if (order == null) {
              return const Center(child: CircularProgressIndicator(color: authPrimary));
            }
            if (order.status != OrderStatus.confirmed) {
              return _PendingView(order: order, confirming: _confirming, onConfirm: _confirmPayment);
            }
            return StreamBuilder<List<Ticket>>(
              stream: OrderService.instance.watchOrderTickets(order.id),
              builder: (context, ticketSnap) {
                final tickets = ticketSnap.data ?? const <Ticket>[];
                return _ConfirmedView(
                  order: order,
                  tickets: tickets,
                  sharing: _sharing,
                  onShare: tickets.isEmpty ? null : () => _share(order, tickets),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _PendingView extends StatelessWidget {
  final TicketOrder order;
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
          Text('Demande de paiement envoyée', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: authInk)),
          const SizedBox(height: 10),
          Text(
            'Une demande de ${fmt.format(order.totalAmount)} XAF a été envoyée par ${paymentMethodLabel(order.paymentMethod)} au ${order.paymentPhone}. '
            'Validez-la sur votre téléphone, puis confirmez ci-dessous.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 13.5, color: authMuted, height: 1.5),
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
                  : Text('J\'ai validé le paiement', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmedView extends StatelessWidget {
  final TicketOrder order;
  final List<Ticket> tickets;
  final bool sharing;
  final VoidCallback? onShare;

  const _ConfirmedView({required this.order, required this.tickets, required this.sharing, required this.onShare});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Center(
          child: Column(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(color: Color(0x1A1E9E6B), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle, size: 42, color: Color(0xFF1E9E6B)),
              ),
              const SizedBox(height: 16),
              Text('Paiement confirmé', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: authInk)),
              const SizedBox(height: 6),
              Text(order.eventTitle, style: GoogleFonts.poppins(fontSize: 13.5, color: authMuted)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        for (final ticket in tickets) _TicketCard(ticket: ticket),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: sharing ? null : onShare,
            icon: sharing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
            label: Text('Partager les billets (PDF)', style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: authPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }
}

class _TicketCard extends StatelessWidget {
  final Ticket ticket;

  const _TicketCard({required this.ticket});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: authBorder), borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Text(ticket.ticketTypeName, style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w700, color: authInk)),
          if (ticket.seanceName != null) ...[
            const SizedBox(height: 3),
            Text(ticket.seanceName!, style: GoogleFonts.poppins(fontSize: 12, color: authMuted)),
          ],
          const SizedBox(height: 16),
          QrImageView(data: ticket.code, size: 140, backgroundColor: Colors.white),
          const SizedBox(height: 12),
          Text(ticket.code, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 2, color: authInk)),
        ],
      ),
    );
  }
}
