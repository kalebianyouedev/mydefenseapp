import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/event.dart';
import '../models/organisation.dart';
import '../services/event_service.dart';
import '../widgets/auth_widgets.dart' show authPrimary, authInk, authMuted, authBorder;
import 'create_event_screen.dart';
import 'event_management_screen.dart';

/// Liste des événements d'une organisation (brouillons, publiés,
/// annulés) avec accès à la création d'un nouvel événement. Ouvert
/// depuis "Tableau de bord" -> tuile "Événements".
class EventsListScreen extends StatelessWidget {
  final Organisation organisation;

  const EventsListScreen({super.key, required this.organisation});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: authInk,
        title: Text('Événements — ${organisation.name}',
            style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: authInk)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final eventId = await Navigator.of(context).push<String>(
            MaterialPageRoute(builder: (_) => CreateEventScreen(organisation: organisation)),
          );
          if (eventId != null && context.mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => EventManagementScreen(eventId: eventId)),
            );
          }
        },
        backgroundColor: authPrimary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Nouvel événement', style: GoogleFonts.nunito(fontWeight: FontWeight.w600, color: Colors.white)),
      ),
      body: SafeArea(
        child: StreamBuilder<List<Event>>(
          stream: EventService.instance.watchByOrganisation(organisation.id),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: authPrimary));
            }
            final events = snapshot.data!;
            if (events.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: const BoxDecoration(color: Color(0xFFF4F4F6), shape: BoxShape.circle),
                        child: const Icon(Icons.event_outlined, size: 36, color: authMuted),
                      ),
                      const SizedBox(height: 18),
                      Text('Aucun événement', style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w700, color: authInk)),
                      const SizedBox(height: 6),
                      Text('Créez votre premier événement avec le bouton ci-dessous.',
                          textAlign: TextAlign.center, style: GoogleFonts.nunito(fontSize: 13, color: authMuted)),
                    ],
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              itemCount: events.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _EventListTile(event: events[i]),
            );
          },
        ),
      ),
    );
  }
}

class _EventListTile extends StatelessWidget {
  final Event event;

  const _EventListTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final seance = event.primarySeance;
    final (label, color) = switch (event.status) {
      EventStatus.draft => ('Brouillon', authMuted),
      EventStatus.published => ('Publié', const Color(0xFF1E9E6B)),
      EventStatus.cancelled => ('Annulé', authPrimary),
    };
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => EventManagementScreen(eventId: event.id)),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: authBorder), borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: authInk,
                    image: event.coverImageUrl != null
                        ? DecorationImage(image: NetworkImage(event.coverImageUrl!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: event.coverImageUrl == null
                      ? const Icon(Icons.event_outlined, color: Colors.white70)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                      child: Text(label, style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                    ),
                    const SizedBox(height: 6),
                    Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: authInk)),
                    if (seance != null) ...[
                      const SizedBox(height: 3),
                      Text(DateFormat('d MMM y', 'fr_FR').format(seance.start),
                          style: GoogleFonts.nunito(fontSize: 12, color: authMuted)),
                    ],
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
