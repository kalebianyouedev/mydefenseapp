import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'models/event.dart';
import 'models/organisation.dart';
import 'screens/account_screen.dart';
import 'screens/event_detail_screen.dart';
import 'screens/my_orders_screen.dart';
import 'screens/organisation_hub_screen.dart';
import 'screens/public_votes_screen.dart';
import 'screens/quick_create_flow.dart';
import 'services/event_service.dart';
import 'services/organisation_service.dart';
import 'widgets/auth_widgets.dart'
    show authPrimary, authInk, authMuted, authBorder;
import 'widgets/liquid_bottom_nav.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: switch (_navIndex) {
          0 => const _EventsTab(),
          1 => const PublicVotesScreen(),
          3 => const MyOrdersScreen(),
          4 => const AccountScreen(),
          _ => const SizedBox.shrink(),
        },
      ),
      bottomNavigationBar: LiquidGlassNavBar(
        currentIndex: _navIndex,
        onTap: (index) {
          if (index == 2) {
            openQuickCreateFlow(context);
          } else {
            setState(() => _navIndex = index);
          }
        },
      ),
    );
  }
}

/// Petite icône, à côté des notifications, qui n'apparaît qu'une fois
/// qu'une organisation existe et ouvre son tableau de bord (événements,
/// votes, campagnes, membres, portefeuille, organisations).
class _OrgHubButton extends StatelessWidget {
  const _OrgHubButton();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Organisation>>(
      stream: OrganisationService.instance.watchMine(),
      builder: (context, snapshot) {
        final hasOrganisation = (snapshot.data ?? const []).isNotEmpty;
        if (!hasOrganisation) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(left: 12),
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const OrganisationHubScreen()),
            ),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                border: Border.all(color: authBorder),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.dashboard_customize_outlined,
                  size: 20, color: authInk),
            ),
          ),
        );
      },
    );
  }
}

class _EventsTab extends StatefulWidget {
  const _EventsTab();

  @override
  State<_EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<_EventsTab> {
  String _query = '';

  List<Event> _filter(List<Event> events) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return events;
    return events
        .where((e) =>
            e.title.toLowerCase().contains(q) ||
            e.venue.toLowerCase().contains(q) ||
            e.city.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F4F6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    style: GoogleFonts.poppins(fontSize: 14, color: authInk),
                    decoration: InputDecoration(
                      hintText: 'Search for an event...',
                      hintStyle:
                          GoogleFonts.poppins(fontSize: 14, color: authMuted),
                      prefixIcon: const Icon(Icons.search,
                          size: 20, color: authMuted),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  border: Border.all(color: authBorder),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    const Center(
                      child: Icon(Icons.notifications_outlined,
                          size: 20, color: authInk),
                    ),
                    Positioned(
                      top: 9,
                      right: 9,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: authPrimary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const _OrgHubButton(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<List<Event>>(
            stream: EventService.instance.watchPublished(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: authPrimary));
              }
              final events = _filter(snapshot.data!);
              if (events.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event_busy_outlined,
                            size: 40, color: authMuted),
                        const SizedBox(height: 12),
                        Text(
                          'Aucun événement pour le moment',
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: authInk),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                itemCount: events.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) =>
                    _EventCard(event: events[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final seance = event.primarySeance;
    final dateLabel =
        seance == null ? '' : DateFormat('EEE d MMM', 'fr_FR').format(seance.start);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: authBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            child: SizedBox(
              height: 150,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: authInk,
                      image: event.coverImageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(event.coverImageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: event.coverImageUrl == null
                        ? const Center(
                            child: Icon(Icons.festival_outlined,
                                size: 44, color: Colors.white70),
                          )
                        : null,
                  ),
                  if (event.organisationName.isNotEmpty)
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          event.organisationName,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: authInk,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: GoogleFonts.poppins(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: authInk,
                  ),
                ),
                if (dateLabel.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 14, color: authMuted),
                      const SizedBox(width: 6),
                      Text(
                        dateLabel,
                        style: GoogleFonts.poppins(
                            fontSize: 12.5, color: authMuted),
                      ),
                    ],
                  ),
                ],
                if (event.venue.isNotEmpty || event.city.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined,
                          size: 14, color: authMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          [event.venue, event.city]
                              .where((e) => e.isNotEmpty)
                              .join(', '),
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              fontSize: 12.5, color: authMuted),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.isFree ? 'Gratuit' : 'Billets disponibles',
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: authPrimary,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EventDetailScreen(event: event),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: authPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'View this event',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
