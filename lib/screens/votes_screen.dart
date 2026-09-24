import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/organisation.dart';
import '../models/vote_campaign.dart';
import '../services/vote_service.dart';
import '../widgets/auth_widgets.dart' show authPrimary, authInk, authMuted, authBorder;
import 'create_vote_campaign_screen.dart';
import 'vote_campaign_management_screen.dart';

/// Liste des campagnes de vote d'une organisation, avec accès à la
/// création d'une nouvelle campagne. Ouvert depuis "Tableau de bord" ->
/// tuile "Votes".
class VotesScreen extends StatelessWidget {
  final Organisation organisation;

  const VotesScreen({super.key, required this.organisation});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: authInk,
        title: Text('Votes — ${organisation.name}',
            style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: authInk)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final campaignId = await Navigator.of(context).push<String>(
            MaterialPageRoute(builder: (_) => CreateVoteCampaignScreen(organisation: organisation)),
          );
          if (campaignId != null && context.mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => VoteCampaignManagementScreen(campaignId: campaignId)),
            );
          }
        },
        backgroundColor: authPrimary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Nouvelle campagne', style: GoogleFonts.nunito(fontWeight: FontWeight.w600, color: Colors.white)),
      ),
      body: SafeArea(
        child: StreamBuilder<List<VoteCampaign>>(
          stream: VoteService.instance.watchByOrganisation(organisation.id),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: authPrimary));
            }
            final campaigns = snapshot.data!;
            if (campaigns.isEmpty) {
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
                        child: const Icon(Icons.emoji_events_outlined, size: 36, color: authMuted),
                      ),
                      const SizedBox(height: 18),
                      Text('Aucune campagne de vote', style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w700, color: authInk)),
                      const SizedBox(height: 6),
                      Text('Créez votre première campagne avec le bouton ci-dessous.',
                          textAlign: TextAlign.center, style: GoogleFonts.nunito(fontSize: 13, color: authMuted)),
                    ],
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              itemCount: campaigns.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _CampaignTile(campaign: campaigns[i]),
            );
          },
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
