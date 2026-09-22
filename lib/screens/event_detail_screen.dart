import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/event.dart';
import '../models/order.dart';
import '../models/ticket_type.dart';
import '../services/event_service.dart';
import '../widgets/auth_widgets.dart' show authPrimary, authInk, authMuted, authBorder;
import 'checkout_screen.dart';

/// Page publique d'un événement : détails, séances et types de billets
/// avec sélecteur de quantité, puis passage au checkout. Ouverte depuis
/// "View this event" sur la page d'accueil.
class EventDetailScreen extends StatefulWidget {
  final Event event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  Seance? _selectedSeance;
  final Map<String, int> _quantities = {};

  @override
  void initState() {
    super.initState();
    _selectedSeance = widget.event.primarySeance ?? (widget.event.seances.isNotEmpty ? widget.event.seances.first : null);
    EventService.instance.incrementViews(widget.event.id);
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<List<TicketType>>(
        stream: EventService.instance.watchTicketTypes(event.id),
        builder: (context, snapshot) {
          final allTypes = snapshot.data ?? const <TicketType>[];
          final types = _selectedSeance == null
              ? allTypes
              : allTypes.where((t) => t.seanceId == _selectedSeance!.id).toList();
          final total = types.fold<num>(0, (sum, t) => sum + t.price * (_quantities[t.id] ?? 0));
          final ticketCount = _quantities.values.fold<int>(0, (sum, q) => sum + q);

          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _Cover(event: event)),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (event.organisationName.isNotEmpty)
                                Text(event.organisationName.toUpperCase(),
                                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: authPrimary, letterSpacing: 0.6)),
                              const SizedBox(height: 4),
                              Text(event.title, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: authInk)),
                              const SizedBox(height: 10),
                              if (event.venue.isNotEmpty || event.city.isNotEmpty)
                                _iconLine(Icons.place_outlined, [event.venue, event.city].where((e) => e.isNotEmpty).join(', ')),
                              if (event.description.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Text(event.description, style: GoogleFonts.poppins(fontSize: 13.5, color: authInk, height: 1.5)),
                              ],
                              if (event.seances.length > 1) ...[
                                const SizedBox(height: 20),
                                Text('Séances', style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w700, color: authInk)),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: event.seances.map((s) {
                                    final active = s.id == _selectedSeance?.id;
                                    return GestureDetector(
                                      onTap: () => setState(() => _selectedSeance = s),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                        decoration: BoxDecoration(
                                          color: active ? authInk : Colors.white,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: active ? authInk : authBorder),
                                        ),
                                        child: Text(
                                          s.name ?? DateFormat('d MMM • HH:mm', 'fr_FR').format(s.start),
                                          style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: active ? Colors.white : authMuted),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ] else if (_selectedSeance != null) ...[
                                const SizedBox(height: 14),
                                _iconLine(Icons.calendar_today_outlined,
                                    DateFormat("EEEE d MMMM y 'à' HH'h'mm", 'fr_FR').format(_selectedSeance!.start)),
                              ],
                              const SizedBox(height: 22),
                              Text('Billets', style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w700, color: authInk)),
                              const SizedBox(height: 10),
                              if (types.isEmpty)
                                Text('Aucun billet disponible pour le moment.', style: GoogleFonts.poppins(fontSize: 13, color: authMuted))
                              else
                                ...types.map((t) => _TicketTypeSelector(
                                      type: t,
                                      quantity: _quantities[t.id] ?? 0,
                                      onChanged: (q) => setState(() => _quantities[t.id] = q),
                                    )),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (types.isNotEmpty)
                  _BuyBar(
                    total: total,
                    ticketCount: ticketCount,
                    onBuy: ticketCount == 0
                        ? null
                        : () {
                            final items = types
                                .where((t) => (_quantities[t.id] ?? 0) > 0)
                                .map((t) => OrderItem(
                                      ticketTypeId: t.id,
                                      ticketTypeName: t.name,
                                      seanceId: t.seanceId,
                                      seanceName: _selectedSeance?.name ??
                                          (_selectedSeance != null
                                              ? DateFormat('d MMM y • HH:mm', 'fr_FR').format(_selectedSeance!.start)
                                              : ''),
                                      seanceStart: _selectedSeance?.start,
                                      quantity: _quantities[t.id]!,
                                      unitPrice: t.price,
                                    ))
                                .toList();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CheckoutScreen(event: event, items: items),
                              ),
                            );
                          },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _iconLine(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: authMuted),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: GoogleFonts.poppins(fontSize: 13, color: authMuted))),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  final Event event;

  const _Cover({required this.event});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 220,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0F2A6B), Color(0xFFE30B4C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            image: event.coverImageUrl != null ? DecorationImage(image: NetworkImage(event.coverImageUrl!), fit: BoxFit.cover) : null,
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            style: IconButton.styleFrom(backgroundColor: Colors.black.withOpacity(0.35)),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _TicketTypeSelector extends StatelessWidget {
  final TicketType type;
  final int quantity;
  final ValueChanged<int> onChanged;

  const _TicketTypeSelector({required this.type, required this.quantity, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern('fr_FR');
    final soldOut = type.isSoldOut;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: authBorder), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type.name, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: authInk)),
                const SizedBox(height: 3),
                Text(
                  soldOut ? 'Épuisé' : '${fmt.format(type.price)} XAF',
                  style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: soldOut ? authPrimary : authMuted),
                ),
              ],
            ),
          ),
          if (!soldOut)
            Row(
              children: [
                _stepperButton(Icons.remove, quantity > 0 ? () => onChanged(quantity - 1) : null),
                SizedBox(width: 28, child: Text('$quantity', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700))),
                _stepperButton(Icons.add, type.remaining == null || quantity < type.remaining! ? () => onChanged(quantity + 1) : null),
              ],
            ),
        ],
      ),
    );
  }

  Widget _stepperButton(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onTap == null ? const Color(0xFFF4F4F6) : authPrimary.withOpacity(0.1),
        ),
        child: Icon(icon, size: 16, color: onTap == null ? authMuted : authPrimary),
      ),
    );
  }
}

class _BuyBar extends StatelessWidget {
  final num total;
  final int ticketCount;
  final VoidCallback? onBuy;

  const _BuyBar({required this.total, required this.ticketCount, required this.onBuy});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern('fr_FR');
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: authBorder))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$ticketCount billet${ticketCount > 1 ? 's' : ''}', style: GoogleFonts.poppins(fontSize: 11.5, color: authMuted)),
                Text('${fmt.format(total)} XAF', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: authInk)),
              ],
            ),
          ),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: onBuy,
              style: ElevatedButton.styleFrom(
                backgroundColor: authPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Acheter', style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
