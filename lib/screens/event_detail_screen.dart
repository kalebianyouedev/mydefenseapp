import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/event.dart';
import '../models/order.dart';
import '../models/ticket_type.dart';
import '../services/event_service.dart';
import '../widgets/auth_widgets.dart' show authPrimary, authAccent, authInk, authMuted, authBorder;
import '../widgets/event_actions.dart';
import '../widgets/event_cover.dart';
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
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(event.organisationName.toUpperCase(),
                                          style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: authPrimary, letterSpacing: 0.6)),
                                    ),
                                    if (event.organisationCertified) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.verified, size: 15, color: Color(0xFF2D6BE0)),
                                    ],
                                    const Spacer(),
                                    FollowOrganisationButton(
                                      organisationId: event.organisationId,
                                      organisationName: event.organisationName,
                                      organisationLogoUrl: event.organisationLogoUrl,
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 4),
                              Text(event.title, style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w700, color: authInk)),
                              const SizedBox(height: 10),
                              // Compteurs à jour en direct (j'aime, boosts).
                              StreamBuilder<Event?>(
                                stream: EventService.instance.watchOne(event.id),
                                builder: (context, snap) {
                                  final live = snap.data ?? event;
                                  return Row(
                                    children: [
                                      EventLikeButton(event: live),
                                      const SizedBox(width: 8),
                                      EventBoostButton(event: live),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 10),
                              if (event.venue.isNotEmpty || event.city.isNotEmpty)
                                _iconLine(Icons.place_outlined, [event.venue, event.city].where((e) => e.isNotEmpty).join(', ')),
                              if (event.description.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Text(event.description, style: GoogleFonts.nunito(fontSize: 13.5, color: authInk, height: 1.5)),
                              ],
                              if (event.gallery.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                Text('Photos', style: GoogleFonts.nunito(fontSize: 13.5, fontWeight: FontWeight.w700, color: authInk)),
                                const SizedBox(height: 10),
                                _Gallery(images: event.gallery),
                              ],
                              if (event.seances.length > 1) ...[
                                const SizedBox(height: 20),
                                Text('Séances', style: GoogleFonts.nunito(fontSize: 13.5, fontWeight: FontWeight.w700, color: authInk)),
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
                                          style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w600, color: active ? Colors.white : authMuted),
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
                              Text('Billets', style: GoogleFonts.nunito(fontSize: 13.5, fontWeight: FontWeight.w700, color: authInk)),
                              const SizedBox(height: 10),
                              if (types.isEmpty)
                                Text('Aucun billet disponible pour le moment.', style: GoogleFonts.nunito(fontSize: 13, color: authMuted))
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
        Expanded(child: Text(text, style: GoogleFonts.nunito(fontSize: 13, color: authMuted))),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  final Event event;

  const _Cover({required this.event});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 340,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Affiche entière sur fond flou : rien n'est rogné.
          EventCover(imageUrl: event.coverImageUrl, fallbackIconSize: 52),
          // Léger dégradé pour garder le bouton retour lisible sur toute photo.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black26, Colors.transparent],
                stops: [0.0, 0.35],
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              style: IconButton.styleFrom(backgroundColor: Colors.black.withValues(alpha: 0.35)),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(event.category.icon, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(event.category.label,
                      style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Galerie de photos de l'événement (en plus de la couverture), en
/// vignettes défilables horizontalement, ouvrables en plein écran.
class _Gallery extends StatelessWidget {
  final List<String> images;

  const _Gallery({required this.images});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final url = images[index];
          return GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _GalleryViewer(images: images, initialIndex: index),
                fullscreenDialog: true,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                url,
                width: 96,
                height: 96,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : Container(width: 96, height: 96, color: const Color(0xFFF4F4F6)),
                errorBuilder: (_, _, _) => Container(
                  width: 96,
                  height: 96,
                  color: const Color(0xFFF4F4F6),
                  child: const Icon(Icons.broken_image_outlined, color: authMuted),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Visionneuse plein écran des photos de la galerie, avec pagination
/// swipeable façon carrousel.
class _GalleryViewer extends StatelessWidget {
  final List<String> images;
  final int initialIndex;

  const _GalleryViewer({required this.images, required this.initialIndex});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: PageController(initialPage: initialIndex),
              itemCount: images.length,
              itemBuilder: (context, index) => Center(
                child: InteractiveViewer(
                  child: Image.network(images[index], fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(backgroundColor: Colors.black.withOpacity(0.35)),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
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
                Text(type.name, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: authInk)),
                const SizedBox(height: 3),
                Text(
                  soldOut ? 'Épuisé' : '${fmt.format(type.price)} XAF',
                  style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w600, color: soldOut ? authPrimary : authMuted),
                ),
              ],
            ),
          ),
          if (!soldOut)
            Row(
              children: [
                _stepperButton(Icons.remove, quantity > 0 ? () => onChanged(quantity - 1) : null),
                SizedBox(width: 28, child: Text('$quantity', textAlign: TextAlign.center, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700))),
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
                Text('$ticketCount billet${ticketCount > 1 ? 's' : ''}', style: GoogleFonts.nunito(fontSize: 11.5, color: authMuted)),
                Text('${fmt.format(total)} XAF', style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w700, color: authInk)),
              ],
            ),
          ),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: onBuy,
              style: ElevatedButton.styleFrom(
                backgroundColor: authAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                shape: const StadiumBorder(),
              ),
              child: Text('Acheter', style: GoogleFonts.nunito(fontSize: 14.5, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
