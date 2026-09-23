import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/order.dart';
import '../models/payment_method.dart';
import '../models/ticket.dart';
import '../services/order_service.dart';
import '../widgets/auth_widgets.dart' show authPrimary, authInk, authMuted, authBorder, showAuthSnack;

/// Suivi d'une commande : tant qu'aucune passerelle Orange Money / MTN
/// Mobile Money réelle n'est branchée, le paiement est confirmé ici à
/// la main (simulateur de l'accusé de réception mobile money). Une fois
/// confirmée, les billets apparaissent avec leur QR code, à présenter à
/// l'entrée (scanné une seule fois par l'organisateur).
class OrderConfirmationScreen extends StatefulWidget {
  final String orderId;

  const OrderConfirmationScreen({super.key, required this.orderId});

  @override
  State<OrderConfirmationScreen> createState() => _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> {
  bool _confirming = false;

  /// Change pour recréer le flux des billets (bouton "Réessayer").
  int _ticketsAttempt = 0;

  Future<void> _confirmPayment() async {
    setState(() => _confirming = true);
    try {
      await OrderService.instance.confirmOrder(widget.orderId);
    } catch (e) {
      if (mounted) {
        showAuthSnack(context, e is StateError ? e.message : 'Échec de la confirmation : $e');
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
              key: ValueKey(_ticketsAttempt),
              stream: OrderService.instance.watchOrderTickets(order.id),
              builder: (context, ticketSnap) {
                return _ConfirmedView(
                  order: order,
                  tickets: ticketSnap.data,
                  error: ticketSnap.hasError,
                  onRetry: () => setState(() => _ticketsAttempt++),
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
  /// null tant que les billets chargent.
  final List<Ticket>? tickets;
  final bool error;
  final VoidCallback onRetry;

  const _ConfirmedView({
    required this.order,
    required this.tickets,
    required this.error,
    required this.onRetry,
  });

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
        if (error)
          _TicketsMessage(
            icon: Icons.wifi_off_rounded,
            text: 'Impossible de charger vos billets. Vérifiez votre connexion.',
            onRetry: onRetry,
          )
        else if (tickets == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(color: authPrimary)),
          )
        else if (tickets!.isEmpty)
          _TicketsMessage(
            icon: Icons.confirmation_number_outlined,
            text: 'Vos billets sont en cours de génération.',
            onRetry: onRetry,
          )
        else
          for (final ticket in tickets!) _TicketCard(ticket: ticket),
      ],
    );
  }
}

class _TicketCard extends StatelessWidget {
  final Ticket ticket;

  const _TicketCard({required this.ticket});

  static const _statusLabels = {
    TicketStatus.valid: 'Valide',
    TicketStatus.used: 'Utilisé',
    TicketStatus.cancelled: 'Annulé',
  };
  static const _statusColors = {
    TicketStatus.valid: Color(0xFF1E9E6B),
    TicketStatus.used: authMuted,
    TicketStatus.cancelled: authPrimary,
  };

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern('fr_FR');
    final dateFmt = DateFormat("EEE d MMM y • HH'h'mm", 'fr_FR');
    final statusColor = _statusColors[ticket.status]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Photo de couverture + titre + badge de statut.
            SizedBox(
              height: 150,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ticket.eventCoverImageUrl != null
                      ? Image.network(
                          ticket.eventCoverImageUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) =>
                              progress == null ? child : _coverFallback(),
                          errorBuilder: (_, _, _) => _coverFallback(),
                        )
                      : _coverFallback(),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.05),
                          Colors.black.withOpacity(0.70),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 14,
                    top: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _statusLabels[ticket.status]!,
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ticket.eventTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ticket.ticketTypeName,
                          style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.white70, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Détails (date, lieu, prix).
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Column(
                children: [
                  if (ticket.seanceStart != null)
                    _infoRow(Icons.calendar_today_outlined, dateFmt.format(ticket.seanceStart!)),
                  if (ticket.venue.isNotEmpty || ticket.city.isNotEmpty)
                    _infoRow(Icons.place_outlined,
                        [ticket.venue, ticket.city].where((e) => e.isNotEmpty).join(', ')),
                  if (ticket.buyerName.isNotEmpty)
                    _infoRow(Icons.person_outline, ticket.buyerName),
                  _infoRow(Icons.payments_outlined, '${fmt.format(ticket.price)} XAF'),
                ],
              ),
            ),
            Container(color: Colors.white, child: _DashedDivider()),
            // QR code.
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: authBorder),
                    ),
                    child: Opacity(
                      opacity: ticket.status == TicketStatus.valid ? 1 : 0.25,
                      child: QrImageView(data: ticket.code, size: 200, backgroundColor: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    ticket.code,
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 3, color: authInk),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    switch (ticket.status) {
                      TicketStatus.valid => 'Présentez ce QR code à l\'entrée',
                      TicketStatus.used => ticket.checkedInAt != null
                          ? 'Billet scanné le ${DateFormat("d MMM 'à' HH'h'mm", 'fr_FR').format(ticket.checkedInAt!)}'
                          : 'Billet déjà scanné',
                      TicketStatus.cancelled => 'Billet annulé',
                    },
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: ticket.status == TicketStatus.valid ? authMuted : statusColor,
                      fontWeight: ticket.status == TicketStatus.valid ? FontWeight.w400 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverFallback() {
    return Container(
      decoration: const BoxDecoration(color: authInk),
      child: const Center(child: Icon(Icons.festival_outlined, size: 36, color: Colors.white70)),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: authMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(fontSize: 13, color: authInk, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketsMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onRetry;

  const _TicketsMessage({required this.icon, required this.text, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, size: 36, color: authMuted),
          const SizedBox(height: 10),
          Text(text,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13.5, color: authInk)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text('Réessayer', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: authPrimary,
              side: const BorderSide(color: authPrimary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne pointillée façon "détachez ici", entre les infos et le QR code.
class _DashedDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const dashWidth = 6.0;
          const dashSpace = 5.0;
          final count = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
          return Row(
            children: List.generate(
              count,
              (_) => Padding(
                padding: const EdgeInsets.only(right: dashSpace),
                child: Container(width: dashWidth, height: 1.4, color: authBorder),
              ),
            ),
          );
        },
      ),
    );
  }
}
