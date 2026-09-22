import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/order.dart';
import '../services/order_service.dart';
import '../widgets/auth_widgets.dart' show authPrimary, authInk, authMuted, authBorder;
import 'order_confirmation_screen.dart';

/// Mes commandes : historique des billets achetés (en attente ou
/// confirmés), avec accès au PDF. Onglet "Orders" de la navigation
/// principale.
class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TicketOrder>>(
      stream: OrderService.instance.watchMyOrders(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: authPrimary));
        }
        final orders = snapshot.data!;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Mes commandes', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: authInk)),
              ),
            ),
            Expanded(
              child: orders.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 88,
                              height: 88,
                              decoration: const BoxDecoration(color: Color(0xFFF4F4F6), shape: BoxShape.circle),
                              child: const Icon(Icons.confirmation_number_outlined, size: 36, color: authMuted),
                            ),
                            const SizedBox(height: 18),
                            Text('Aucune commande', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: authInk)),
                            const SizedBox(height: 6),
                            Text('Vos billets achetés apparaîtront ici.', style: GoogleFonts.poppins(fontSize: 13, color: authMuted)),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                      itemCount: orders.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => _OrderTile(order: orders[i]),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _OrderTile extends StatelessWidget {
  final TicketOrder order;

  const _OrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern('fr_FR');
    final confirmed = order.status == OrderStatus.confirmed;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => OrderConfirmationScreen(orderId: order.id)),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(border: Border.all(color: authBorder), borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (confirmed ? const Color(0xFF1E9E6B) : authMuted).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  confirmed ? Icons.confirmation_number_outlined : Icons.hourglass_top_outlined,
                  color: confirmed ? const Color(0xFF1E9E6B) : authMuted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.eventTitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: authInk)),
                    const SizedBox(height: 3),
                    Text(
                      '${order.ticketCount} billet${order.ticketCount > 1 ? 's' : ''} · ${fmt.format(order.totalAmount)} XAF · ${confirmed ? 'Confirmée' : 'En attente'}',
                      style: GoogleFonts.poppins(fontSize: 12, color: authMuted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: authMuted),
            ],
          ),
        ),
      ),
    );
  }
}
