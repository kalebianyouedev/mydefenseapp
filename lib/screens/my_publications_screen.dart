import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/event.dart';
import '../models/vote_campaign.dart';
import '../services/event_service.dart';
import '../services/vote_service.dart';
import '../widgets/auth_widgets.dart' show authPrimary, authInk, authMuted, authBorder;
import 'event_management_screen.dart';
import 'vote_campaign_management_screen.dart';

/// "Mes publications" : tout ce que l'utilisateur a créé, toutes ses
/// organisations confondues — ses événements et ses campagnes de vote,
/// dans deux onglets. Occupe la place laissée par l'ancien onglet
/// "Posts" dans la barre de navigation.
class MyPublicationsScreen extends StatelessWidget {
  const MyPublicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: authInk,
          title: Text('Mes publications', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: authInk)),
          bottom: TabBar(
            labelColor: authPrimary,
            unselectedLabelColor: authMuted,
            indicatorColor: authPrimary,
            labelStyle: GoogleFonts.nunito(fontSize: 13.5, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.nunito(fontSize: 13.5, fontWeight: FontWeight.w500),
            tabs: const [
              Tab(text: 'Événements'),
              Tab(text: 'Votes'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _MyEventsTab(),
            _MyVotesTab(),
          ],
        ),
      ),
    );
  }
}

class _MyEventsTab extends StatelessWidget {
  const _MyEventsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Event>>(
      stream: EventService.instance.watchMine(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: authPrimary));
        }
        final events = snapshot.data!;
        if (events.isEmpty) {
          return _EmptyTab(
            icon: Icons.event_outlined,
            title: 'Aucun événement',
            message: 'Vos événements créés apparaîtront ici.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          itemCount: events.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _EventTile(event: events[i]),
        );
      },
    );
  }
}

class _MyVotesTab extends StatelessWidget {
  const _MyVotesTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<VoteCampaign>>(
      stream: VoteService.instance.watchMine(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: authPrimary));
        }
        final campaigns = snapshot.data!;
        if (campaigns.isEmpty) {
          return _EmptyTab(
            icon: Icons.how_to_vote_outlined,
            title: 'Aucune campagne de vote',
            message: 'Vos campagnes créées apparaîtront ici.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          itemCount: campaigns.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _CampaignTile(campaign: campaigns[i]),
        );
      },
    );
  }
}

class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyTab({required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
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
              child: Icon(icon, size: 36, color: authMuted),
            ),
            const SizedBox(height: 18),
            Text(title, style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w700, color: authInk)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: GoogleFonts.nunito(fontSize: 13, color: authMuted)),
            const SizedBox(height: 8),
            Text('Utilisez le bouton "Posts" pour en créer un.',
                textAlign: TextAlign.center, style: GoogleFonts.nunito(fontSize: 12, color: authMuted)),
          ],
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final Event event;

  const _EventTile({required this.event});

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
                    Text(event.organisationName, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(fontSize: 11.5, color: authMuted)),
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

class _CampaignTile extends StatelessWidget {
  final VoteCampaign campaign;

  const _CampaignTile({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (campaign.status) {
      VoteCampaignStatus.draft => ('Brouillon', authMuted),
      VoteCampaignStatus.active => ('Actif', const Color(0xFF1E9E6B)),
      VoteCampaignStatus.ended => ('Terminé', authMuted),
      VoteCampaignStatus.cancelled => ('Annulé', authPrimary),
    };
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => VoteCampaignManagementScreen(campaignId: campaign.id)),
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
                    image: campaign.coverImageUrl != null
                        ? DecorationImage(image: NetworkImage(campaign.coverImageUrl!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: campaign.coverImageUrl == null
                      ? const Icon(Icons.emoji_events_outlined, color: Colors.white70)
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
                    Text(campaign.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: authInk)),
                    Text(campaign.organisationName, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(fontSize: 11.5, color: authMuted)),
                    if (campaign.endsAt != null) ...[
                      const SizedBox(height: 3),
                      Text('Fin le ${DateFormat('d MMM y', 'fr_FR').format(campaign.endsAt!)}',
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
