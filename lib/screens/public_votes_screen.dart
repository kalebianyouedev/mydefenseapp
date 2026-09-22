import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/vote_campaign.dart';
import '../services/vote_service.dart';
import '../widgets/auth_widgets.dart' show authPrimary, authInk, authMuted, authBorder;
import 'public_vote_campaign_screen.dart';

/// Fil public des campagnes de vote actives, toutes organisations
/// confondues. Ouvert depuis l'icône "Votes" de l'accueil.
class PublicVotesScreen extends StatelessWidget {
  const PublicVotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: authInk,
        title: Text('Votes en ligne', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: authInk)),
      ),
      body: SafeArea(
        child: StreamBuilder<List<VoteCampaign>>(
          stream: VoteService.instance.watchActive(),
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
                        child: const Icon(Icons.how_to_vote_outlined, size: 36, color: authMuted),
                      ),
                      const SizedBox(height: 18),
                      Text('Aucun vote en cours', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: authInk)),
                      const SizedBox(height: 6),
                      Text('Revenez plus tard pour voter pour vos favoris.',
                          textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 13, color: authMuted)),
                    ],
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              itemCount: campaigns.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, i) => _CampaignCard(campaign: campaigns[i]),
            );
          },
        ),
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final VoteCampaign campaign;

  const _CampaignCard({required this.campaign});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PublicVoteCampaignScreen(campaign: campaign)),
        ),
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: authBorder), borderRadius: BorderRadius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 130,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: authInk,
                        image: campaign.coverImageUrl != null
                            ? DecorationImage(image: NetworkImage(campaign.coverImageUrl!), fit: BoxFit.cover)
                            : null,
                      ),
                      child: campaign.coverImageUrl == null
                          ? const Center(child: Icon(Icons.emoji_events_outlined, size: 40, color: Colors.white70))
                          : null,
                    ),
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.92), borderRadius: BorderRadius.circular(20)),
                        child: Text(campaign.organisationName,
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: authInk)),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(campaign.title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: authInk)),
                    if (campaign.endsAt != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 14, color: authMuted),
                          const SizedBox(width: 6),
                          Text('Fin le ${DateFormat('d MMM y', 'fr_FR').format(campaign.endsAt!)}',
                              style: GoogleFonts.poppins(fontSize: 12, color: authMuted)),
                        ],
                      ),
                    ],
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
