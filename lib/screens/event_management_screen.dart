import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/event.dart';
import '../models/order.dart';
import '../models/organisation.dart';
import '../models/ticket.dart';
import '../models/ticket_type.dart';
import '../services/event_service.dart';
import '../services/order_service.dart';
import '../widgets/auth_widgets.dart'
    show authPrimary, authInk, authMuted, authBorder, showAuthSnack;
import 'create_event_screen.dart';
import 'manage_promo_codes_screen.dart';
import 'manage_ticket_types_screen.dart';
import 'scan_checkin_screen.dart';

/// Part de la recette qui reste à la plateforme sur chaque billet vendu.
/// Aucune vraie facturation n'est branchée : sert uniquement à afficher
/// la vue financière du tableau de bord (voir la maquette "Nouvel
/// événement" -> tableau de bord).
const _platformCommissionRate = 0.10;

enum _FinancialPeriod { sevenDays, thirtyDays, thisMonth, allTime }

/// Tableau de bord d'un événement : actions (modifier, scanner, billets,
/// codes promo, lien de boost, export CSV, publier/annuler/supprimer),
/// statistiques, vue financière et liste des billets vendus. Adaptation
/// mobile de la maquette web.
class EventManagementScreen extends StatefulWidget {
  final String eventId;

  const EventManagementScreen({super.key, required this.eventId});

  @override
  State<EventManagementScreen> createState() => _EventManagementScreenState();
}

class _EventManagementScreenState extends State<EventManagementScreen> {
  _FinancialPeriod _period = _FinancialPeriod.allTime;

  Future<void> _edit(Event event) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateEventScreen(
          organisation: _fakeOrganisationFrom(event),
          existing: event,
        ),
      ),
    );
  }

  Future<void> _publish(Event event) async {
    try {
      await EventService.instance.publish(event.id);
      if (mounted) showAuthSnack(context, 'Événement publié.');
    } catch (e) {
      if (mounted) {
        showAuthSnack(context, e is StateError ? e.message : 'Échec de la publication.');
      }
    }
  }

  Future<void> _cancel(Event event) async {
    final confirm = await _confirm(
      title: 'Annuler l\'événement ?',
      message: 'Il ne sera plus visible du public. Vous pourrez le repasser en brouillon ensuite.',
      confirmLabel: 'Annuler l\'événement',
    );
    if (confirm != true) return;
    await EventService.instance.cancel(event.id);
  }

  Future<void> _delete(Event event) async {
    final confirm = await _confirm(
      title: 'Supprimer l\'événement ?',
      message: 'Cette action est définitive. Les billets déjà vendus ne seront pas remboursés automatiquement.',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (confirm != true) return;
    await EventService.instance.delete(event.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Retour')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel, style: TextStyle(color: destructive ? authPrimary : null)),
          ),
        ],
      ),
    );
  }

  void _copyBoostLink(Event event) {
    final link = 'https://mydefenseoff.app/e/${event.id}';
    Clipboard.setData(ClipboardData(text: link));
    showAuthSnack(context, 'Lien copié : $link');
  }

  Future<void> _exportCsv(Event event) async {
    final tickets = await OrderService.instance.watchEventTickets(event.id).first;
    final buffer = StringBuffer('Acheteur,Type de billet,Statut,Check-in\n');
    for (final t in tickets) {
      final checkIn = t.checkedInAt == null
          ? ''
          : DateFormat('d/MM/y HH:mm').format(t.checkedInAt!);
      buffer.writeln('"${t.buyerName}","${t.ticketTypeName}","${_ticketStatusLabel(t.status)}","$checkIn"');
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/billets_${event.id}.csv');
    await file.writeAsString(buffer.toString());
    await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')], text: 'Export billets — ${event.title}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<Event?>(
        stream: EventService.instance.watchOne(widget.eventId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: authPrimary));
          }
          final event = snapshot.data;
          if (event == null) {
            return const Center(child: Text('Événement introuvable.'));
          }
          return SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _CoverHeader(event: event)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StatusBadge(status: event.status),
                        const SizedBox(height: 10),
                        Text(event.title,
                            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: authInk)),
                        if (event.description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(event.description, style: GoogleFonts.poppins(fontSize: 13, color: authMuted)),
                        ],
                        const SizedBox(height: 16),
                        _ActionButtons(
                          event: event,
                          onEdit: () => _edit(event),
                          onScan: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => ScanCheckinScreen(event: event)),
                          ),
                          onTickets: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => ManageTicketTypesScreen(event: event)),
                          ),
                          onPromoCodes: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => ManagePromoCodesScreen(event: event)),
                          ),
                          onCopyLink: () => _copyBoostLink(event),
                          onExportCsv: () => _exportCsv(event),
                          onPublish: () => _publish(event),
                          onCancel: () => _cancel(event),
                          onDelete: () => _delete(event),
                        ),
                        const SizedBox(height: 24),
                        _StatsGrid(event: event),
                        const SizedBox(height: 24),
                        Text('Vue financière',
                            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: authInk)),
                        Text('Résumé des paiements confirmés pour cet événement.',
                            style: GoogleFonts.poppins(fontSize: 12, color: authMuted)),
                        const SizedBox(height: 12),
                        _PeriodSelector(value: _period, onChanged: (p) => setState(() => _period = p)),
                        const SizedBox(height: 14),
                        StreamBuilder<List<TicketOrder>>(
                          stream: OrderService.instance.watchEventOrders(event.id),
                          builder: (context, orderSnap) {
                            final orders = (orderSnap.data ?? const <TicketOrder>[])
                                .where((o) => o.status == OrderStatus.confirmed)
                                .where((o) => _withinPeriod(o.createdAt, _period))
                                .toList();
                            final gross = orders.fold<num>(0, (sum, o) => sum + o.totalAmount);
                            final commission = gross * _platformCommissionRate;
                            final net = gross - commission;
                            final ticketsSold = orders.fold<int>(0, (sum, o) => sum + o.ticketCount);
                            return _FinancialGrid(gross: gross, net: net, commission: commission, ticketsSold: ticketsSold);
                          },
                        ),
                        const SizedBox(height: 24),
                        Text('Billets & vérification',
                            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: authInk)),
                        const SizedBox(height: 12),
                        StreamBuilder<List<Ticket>>(
                          stream: OrderService.instance.watchEventTickets(event.id),
                          builder: (context, ticketSnap) {
                            final tickets = ticketSnap.data ?? const <Ticket>[];
                            if (tickets.isEmpty) {
                              return Text('Aucun billet généré pour le moment.',
                                  style: GoogleFonts.poppins(fontSize: 13, color: authMuted));
                            }
                            return Column(children: tickets.map((t) => _TicketRow(ticket: t)).toList());
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _withinPeriod(DateTime? createdAt, _FinancialPeriod period) {
    if (createdAt == null) return period == _FinancialPeriod.allTime;
    final now = DateTime.now();
    switch (period) {
      case _FinancialPeriod.sevenDays:
        return createdAt.isAfter(now.subtract(const Duration(days: 7)));
      case _FinancialPeriod.thirtyDays:
        return createdAt.isAfter(now.subtract(const Duration(days: 30)));
      case _FinancialPeriod.thisMonth:
        return createdAt.year == now.year && createdAt.month == now.month;
      case _FinancialPeriod.allTime:
        return true;
    }
  }
}

String _ticketStatusLabel(TicketStatus status) {
  switch (status) {
    case TicketStatus.valid:
      return 'Valide';
    case TicketStatus.used:
      return 'Scanné';
    case TicketStatus.cancelled:
      return 'Annulé';
  }
}

/// [CreateEventScreen] attend une [Organisation] complète pour l'édition
/// (nom/logo affichés dans le formulaire de post, pas utilisés ici) ;
/// reconstruit un objet minimal à partir des champs déjà stockés sur
/// l'événement plutôt que d'aller les rechercher.
Organisation _fakeOrganisationFrom(Event event) {
  return Organisation(
    id: event.organisationId,
    ownerId: event.ownerId,
    name: event.organisationName,
    logoUrl: event.organisationLogoUrl,
  );
}

class _CoverHeader extends StatelessWidget {
  final Event event;

  const _CoverHeader({required this.event});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 190,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F2A6B), Color(0xFFE30B4C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            image: event.coverImageUrl != null
                ? DecorationImage(image: NetworkImage(event.coverImageUrl!), fit: BoxFit.cover)
                : null,
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

class _StatusBadge extends StatelessWidget {
  final EventStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      EventStatus.draft => ('Brouillon', authMuted),
      EventStatus.published => ('Publié', const Color(0xFF1E9E6B)),
      EventStatus.cancelled => ('Annulé', authPrimary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final Event event;
  final VoidCallback onEdit;
  final VoidCallback onScan;
  final VoidCallback onTickets;
  final VoidCallback onPromoCodes;
  final VoidCallback onCopyLink;
  final VoidCallback onExportCsv;
  final VoidCallback onPublish;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  const _ActionButtons({
    required this.event,
    required this.onEdit,
    required this.onScan,
    required this.onTickets,
    required this.onPromoCodes,
    required this.onCopyLink,
    required this.onExportCsv,
    required this.onPublish,
    required this.onCancel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip('Modifier', Icons.edit_outlined, onEdit),
        _chip('Scanner', Icons.qr_code_scanner, onScan),
        _chip('Billets', Icons.confirmation_number_outlined, onTickets),
        _chip('Codes promo', Icons.sell_outlined, onPromoCodes),
        _chip('Copier le lien', Icons.link, onCopyLink),
        _chip('Export CSV', Icons.file_download_outlined, onExportCsv),
        if (event.status != EventStatus.published)
          _chip('Publier', Icons.publish_outlined, onPublish, filled: true),
        if (event.status != EventStatus.cancelled)
          _chip('Annuler', Icons.block, onCancel, danger: true),
        _chip('Supprimer', Icons.delete_outline, onDelete, danger: true),
      ],
    );
  }

  Widget _chip(String label, IconData icon, VoidCallback onTap, {bool filled = false, bool danger = false}) {
    final color = danger ? authPrimary : (filled ? Colors.white : authInk);
    final background = filled ? authPrimary : (danger ? authPrimary.withOpacity(0.08) : Colors.white);
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15, color: color),
      label: Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      style: OutlinedButton.styleFrom(
        backgroundColor: background,
        side: BorderSide(color: danger || filled ? Colors.transparent : authBorder),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final Event event;

  const _StatsGrid({required this.event});

  @override
  Widget build(BuildContext context) {
    final seance = event.primarySeance;
    final fmt = DateFormat('d MMM y • HH:mm', 'fr_FR');
    return StreamBuilder<List<TicketType>>(
      stream: EventService.instance.watchTicketTypes(event.id),
      builder: (context, snapshot) {
        final typeCount = (snapshot.data ?? const <TicketType>[]).length;
        final stats = [
          ('Début', seance == null ? '—' : fmt.format(seance.start), Icons.calendar_today_outlined),
          ('Fin', seance == null ? '—' : fmt.format(seance.end), Icons.event_available_outlined),
          ('Lieu', [event.venue, event.city].where((e) => e.isNotEmpty).join(', ').isEmpty ? 'À définir' : [event.venue, event.city].where((e) => e.isNotEmpty).join(', '), Icons.place_outlined),
          ('Types de billets', '$typeCount', Icons.confirmation_number_outlined),
          ('Vues', '${event.views}', Icons.visibility_outlined),
          ('Boosts reçus', '${event.boosts}', Icons.bolt_outlined),
        ];
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.4,
          children: stats
              .map((s) => Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFF9F9FB), borderRadius: BorderRadius.circular(14), border: Border.all(color: authBorder)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(children: [
                          Icon(s.$3, size: 13, color: authMuted),
                          const SizedBox(width: 5),
                          Text(s.$1, style: GoogleFonts.poppins(fontSize: 10.5, color: authMuted, fontWeight: FontWeight.w600)),
                        ]),
                        const SizedBox(height: 4),
                        Text(s.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: authInk)),
                      ],
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final _FinancialPeriod value;
  final ValueChanged<_FinancialPeriod> onChanged;

  const _PeriodSelector({required this.value, required this.onChanged});

  static const _labels = {
    _FinancialPeriod.sevenDays: '7 j',
    _FinancialPeriod.thirtyDays: '30 j',
    _FinancialPeriod.thisMonth: 'Ce mois-ci',
    _FinancialPeriod.allTime: 'Depuis le début',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _FinancialPeriod.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final period = _FinancialPeriod.values[i];
          final active = period == value;
          return GestureDetector(
            onTap: () => onChanged(period),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? authInk : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: active ? authInk : authBorder),
              ),
              child: Text(_labels[period]!, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: active ? Colors.white : authMuted)),
            ),
          );
        },
      ),
    );
  }
}

class _FinancialGrid extends StatelessWidget {
  final num gross;
  final num net;
  final num commission;
  final int ticketsSold;

  const _FinancialGrid({required this.gross, required this.net, required this.commission, required this.ticketsSold});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern('fr_FR');
    final cards = [
      ('Recettes brutes', '${fmt.format(gross)} XAF'),
      ('Net promoteur', '${fmt.format(net)} XAF'),
      ('Commission plateforme', '${fmt.format(commission)} XAF'),
      ('Billets vendus', '$ticketsSold'),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.7,
      children: cards
          .map((c) => Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: authBorder)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(c.$1.toUpperCase(), style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.w700, color: authMuted, letterSpacing: 0.4)),
                    const SizedBox(height: 6),
                    Text(c.$2, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: authInk)),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _TicketRow extends StatelessWidget {
  final Ticket ticket;

  const _TicketRow({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final checkedIn = ticket.status == TicketStatus.used;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: authBorder), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ticket.buyerName, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: authInk)),
                Text(ticket.ticketTypeName, style: GoogleFonts.poppins(fontSize: 11.5, color: authMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: checkedIn ? const Color(0xFF1E9E6B).withOpacity(0.12) : const Color(0xFFF4F4F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              checkedIn ? 'Scanné' : 'Valide',
              style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600, color: checkedIn ? const Color(0xFF1E9E6B) : authMuted),
            ),
          ),
        ],
      ),
    );
  }
}
