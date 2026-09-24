import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/order.dart';
import '../services/order_service.dart';
import '../widgets/auth_widgets.dart' show authPrimary, authInk, authMuted, authBorder, showAuthSnack;
import 'order_confirmation_screen.dart';

/// Mes commandes : historique des billets achetés (en attente ou
/// confirmés). Une commande confirmée affiche le QR code de chaque billet.
/// Onglet "Orders" de la navigation principale.
class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

  /// Retire des commandes de la liste après confirmation. Elles sont
  /// seulement masquées : les billets restent valides et l'organisateur
  /// garde la trace de la vente.
  static Future<void> _remove(BuildContext context, List<TicketOrder> orders) async {
    if (orders.isEmpty) return;
    final single = orders.length == 1;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(single ? 'Supprimer cette commande ?' : 'Supprimer toutes les commandes ?',
            style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: authInk)),
        content: Text(
          single
              ? 'Elle disparaîtra de votre liste. Les billets déjà payés restent valides.'
              : '${orders.length} commandes disparaîtront de votre liste. Les billets déjà payés restent valides.',
          style: GoogleFonts.nunito(fontSize: 13, color: authMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFD93A3A)),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await OrderService.instance.hideOrders(orders.map((o) => o.id).toList());
    } catch (_) {
      if (context.mounted) showAuthSnack(context, 'Échec de la suppression.');
    }
  }

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
              child: Row(
                children: [
                  Expanded(
                    child: Text('Mes commandes', style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w700, color: authInk)),
                  ),
                  if (orders.length > 1)
                    TextButton.icon(
                      onPressed: () => _remove(context, orders),
                      style: TextButton.styleFrom(foregroundColor: authMuted),
                      icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                      label: Text('Tout supprimer', style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ),
                ],
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
                            Text('Aucune commande', style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w700, color: authInk)),
                            const SizedBox(height: 6),
                            Text('Vos billets achetés apparaîtront ici.', style: GoogleFonts.nunito(fontSize: 13, color: authMuted)),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                      itemCount: orders.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => _OrderTile(
                        order: orders[i],
                        onDelete: () => _remove(context, [orders[i]]),
                      ),
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
  final VoidCallback onDelete;

  const _OrderTile({required this.order, required this.onDelete});

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
                        style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: authInk)),
                    const SizedBox(height: 3),
                    Text(
                      '${order.ticketCount} billet${order.ticketCount > 1 ? 's' : ''} · ${fmt.format(order.totalAmount)} XAF · ${confirmed ? 'Voir le QR code' : 'En attente'}',
                      style: GoogleFonts.nunito(fontSize: 12, color: authMuted),
                    ),
                  ],
                ),
              ),
              Icon(confirmed ? Icons.qr_code_2 : Icons.chevron_right,
                  color: confirmed ? authInk : authMuted),
              IconButton(
                onPressed: onDelete,
                tooltip: 'Supprimer',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, size: 20, color: authMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
