import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/event.dart';
import '../services/event_service.dart';
import '../services/organisation_service.dart';
import '../widgets/auth_widgets.dart' show authPrimary, authInk, authMuted, authBorder;
import '../widgets/event_actions.dart';
import '../widgets/event_cover.dart';
import 'event_detail_screen.dart';

/// "Mes abonnements" (Compte) : organisations suivies. Un tap ouvre les
/// événements publiés de l'organisation.
class MyFollowsScreen extends StatelessWidget {
  const MyFollowsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _appBar('Mes abonnements'),
      body: StreamBuilder<List<FollowedOrganisation>>(
        stream: OrganisationService.instance.watchFollowed(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: authPrimary));
          final orgs = snap.data!;
          if (orgs.isEmpty) {
            return const _Empty(
              icon: Icons.groups_outlined,
              title: 'Aucun abonnement',
              subtitle: "Abonnez-vous à une organisation depuis un événement ou un vote pour la retrouver ici.",
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            itemCount: orgs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final o = orgs[i];
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => _OrganisationEventsScreen(organisation: o)),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(border: Border.all(color: authBorder), borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        _OrgAvatar(organisation: o),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(o.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: authInk)),
                        ),
                        FollowOrganisationButton(
                          organisationId: o.id,
                          organisationName: o.name,
                          organisationLogoUrl: o.logoUrl,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _OrganisationEventsScreen extends StatelessWidget {
  final FollowedOrganisation organisation;

  const _OrganisationEventsScreen({required this.organisation});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _appBar(organisation.name),
      body: StreamBuilder<List<Event>>(
        stream: EventService.instance.watchByOrganisation(organisation.id),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: authPrimary));
          final events = snap.data!.where((e) => e.status == EventStatus.published).toList();
          if (events.isEmpty) {
            return const _Empty(
              icon: Icons.event_busy_outlined,
              title: 'Aucun événement publié',
              subtitle: 'Les prochains événements de cette organisation apparaîtront ici.',
            );
          }
          return _EventList(events: events);
        },
      ),
    );
  }
}

/// "Mes favoris" (Compte) : événements aimés.
class MyFavoritesScreen extends StatelessWidget {
  const MyFavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _appBar('Mes favoris'),
      body: StreamBuilder<List<String>>(
        stream: EventService.instance.watchLikedEventIds(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: authPrimary));
          final ids = snap.data!;
          if (ids.isEmpty) {
            return const _Empty(
              icon: Icons.favorite_border_rounded,
              title: 'Aucun favori',
              subtitle: 'Touchez le cœur d\'un événement pour le retrouver ici.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            itemCount: ids.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => StreamBuilder<Event?>(
              stream: EventService.instance.watchOne(ids[i]),
              builder: (context, snap) {
                final event = snap.data;
                if (event == null) return const SizedBox.shrink();
                return _EventTile(event: event);
              },
            ),
          );
        },
      ),
    );
  }
}

class _EventList extends StatelessWidget {
  final List<Event> events;

  const _EventList({required this.events});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      itemCount: events.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _EventTile(event: events[i]),
    );
  }
}

class _EventTile extends StatelessWidget {
  final Event event;

  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final place = [event.venue, event.city].where((e) => e.isNotEmpty).join(', ');
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
        ),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(border: Border.all(color: authBorder), borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(width: 72, height: 88, child: EventCover(imageUrl: event.coverImageUrl, fallbackIconSize: 26)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: authInk)),
                    if (place.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(place, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(fontSize: 12, color: authMuted)),
                    ],
                    const SizedBox(height: 8),
                    EventLikeButton(event: event),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrgAvatar extends StatelessWidget {
  final FollowedOrganisation organisation;

  const _OrgAvatar({required this.organisation});

  @override
  Widget build(BuildContext context) {
    final logo = organisation.logoUrl;
    return CircleAvatar(
      radius: 22,
      backgroundColor: authPrimary.withValues(alpha: 0.12),
      backgroundImage: logo != null ? NetworkImage(logo) : null,
      child: logo == null
          ? Text(organisation.name.isEmpty ? '?' : organisation.name.substring(0, 1).toUpperCase(),
              style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: authPrimary))
          : null,
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _Empty({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: authMuted),
            const SizedBox(height: 12),
            Text(title, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: authInk)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: GoogleFonts.nunito(fontSize: 13, color: authMuted)),
          ],
        ),
      ),
    );
  }
}

PreferredSizeWidget _appBar(String title) => AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      foregroundColor: authInk,
      title: Text(title, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: authInk)),
    );
