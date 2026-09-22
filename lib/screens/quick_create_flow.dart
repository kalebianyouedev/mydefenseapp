import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/organisation.dart';
import '../widgets/auth_widgets.dart' show authPrimary, authInk, authMuted, authBorder;
import 'create_event_screen.dart';
import 'create_vote_campaign_screen.dart';
import 'event_management_screen.dart';
import 'organisations_screen.dart';
import 'vote_campaign_management_screen.dart';

/// Raccourci du bouton central "Posts" : choisir de publier un
/// événement ou une campagne de vote, sélectionner (ou créer) une
/// organisation, puis enchaîner directement sur l'écran de création
/// correspondant.
Future<void> openQuickCreateFlow(BuildContext context) async {
  final choice = await showModalBottomSheet<_QuickCreateChoice>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _QuickCreateSheet(),
  );
  if (choice == null || !context.mounted) return;

  final organisation = await Navigator.of(context).push<Organisation>(
    MaterialPageRoute(builder: (_) => const OrganisationsScreen(selectMode: true)),
  );
  if (organisation == null || !context.mounted) return;

  if (choice == _QuickCreateChoice.event) {
    final eventId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => CreateEventScreen(organisation: organisation)),
    );
    if (eventId != null && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EventManagementScreen(eventId: eventId)),
      );
    }
  } else {
    final campaignId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => CreateVoteCampaignScreen(organisation: organisation)),
    );
    if (campaignId != null && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => VoteCampaignManagementScreen(campaignId: campaignId)),
      );
    }
  }
}

enum _QuickCreateChoice { event, vote }

class _QuickCreateSheet extends StatelessWidget {
  const _QuickCreateSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: authBorder, borderRadius: BorderRadius.circular(4))),
          ),
          const SizedBox(height: 18),
          Text('Que voulez-vous publier ?', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: authInk)),
          const SizedBox(height: 4),
          Text('Choisissez ensuite (ou créez) l\'organisation qui publie.',
              style: GoogleFonts.poppins(fontSize: 12.5, color: authMuted)),
          const SizedBox(height: 20),
          _ChoiceTile(
            icon: Icons.event_outlined,
            title: 'Un événement',
            subtitle: 'Billetterie, séances, types de billets.',
            onTap: () => Navigator.of(context).pop(_QuickCreateChoice.event),
          ),
          const SizedBox(height: 12),
          _ChoiceTile(
            icon: Icons.how_to_vote_outlined,
            title: 'Une campagne de vote',
            subtitle: 'Catégories, candidats, vote payant.',
            onTap: () => Navigator.of(context).pop(_QuickCreateChoice.vote),
          ),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ChoiceTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(border: Border.all(color: authBorder), borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: authPrimary.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: authPrimary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w700, color: authInk)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: authMuted)),
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
