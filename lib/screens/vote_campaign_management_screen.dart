import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/vote_campaign.dart';
import '../models/vote_order.dart';
import '../services/vote_service.dart';
import '../widgets/auth_widgets.dart'
    show authPrimary, authInk, authMuted, authBorder, showAuthSnack;
import 'manage_vote_categories_screen.dart';
import 'public_vote_campaign_screen.dart';

/// Même taux que le portefeuille (voir kPlatformCommissionRate dans
/// wallet_service.dart) : les votes contribuent au même solde.
const _platformCommissionRate = 0.10;

/// Tableau de bord d'une campagne de vote : statut, actions
/// (activer/terminer/annuler/supprimer), vue financière et accès à la
/// gestion des catégories/candidats.
class VoteCampaignManagementScreen extends StatelessWidget {
  final String campaignId;

  const VoteCampaignManagementScreen({super.key, required this.campaignId});

  Future<void> _setStatus(BuildContext context, VoteCampaignStatus status) async {
    try {
      await VoteService.instance.setStatus(campaignId, status);
    } catch (_) {
      if (context.mounted) showAuthSnack(context, 'Échec de la mise à jour.');
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la campagne ?'),
        content: const Text('Cette action est définitive.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Retour')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: authPrimary)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await VoteService.instance.deleteCampaign(campaignId);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<VoteCampaign?>(
        stream: VoteService.instance.watchOne(campaignId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: authPrimary));
          }
          final campaign = snapshot.data;
          if (campaign == null) {
            return const Center(child: Text('Campagne introuvable.'));
          }
          return SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _CoverHeader(campaign: campaign)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StatusBadge(status: campaign.status),
                        const SizedBox(height: 10),
                        Text(campaign.title,
                            style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w700, color: authInk)),
                        if (campaign.description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(campaign.description, style: GoogleFonts.nunito(fontSize: 13, color: authMuted)),
                        ],
                        if (campaign.endsAt != null) ...[
                          const SizedBox(height: 8),
                          Text('Fin le ${DateFormat("d MMMM y 'à' HH'h'mm", 'fr_FR').format(campaign.endsAt!)}',
                              style: GoogleFonts.nunito(fontSize: 12.5, color: authMuted)),
                        ],
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _ActionChip(
                              icon: Icons.category_outlined,
                              label: 'Catégories',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => ManageVoteCategoriesScreen(campaign: campaign)),
                              ),
                            ),
                            _ActionChip(
                              icon: Icons.visibility_outlined,
                              label: 'Page publique',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => PublicVoteCampaignScreen(campaign: campaign)),
                              ),
                            ),
                            if (campaign.status == VoteCampaignStatus.draft)
                              _ActionChip(
                                icon: Icons.play_arrow_rounded,
                                label: 'Activer',
                                highlighted: true,
                                onTap: () => _setStatus(context, VoteCampaignStatus.active),
                              ),
                            if (campaign.status == VoteCampaignStatus.active) ...[
                              _ActionChip(
                                icon: Icons.stop_circle_outlined,
                                label: 'Terminer',
                                onTap: () => _setStatus(context, VoteCampaignStatus.ended),
                              ),
                              _ActionChip(
                                icon: Icons.cancel_outlined,
                                label: 'Annuler',
                                destructive: true,
                                onTap: () => _setStatus(context, VoteCampaignStatus.cancelled),
                              ),
                            ],
                            _ActionChip(
                              icon: Icons.delete_outline,
                              label: 'Supprimer',
                              destructive: true,
                              onTap: () => _delete(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 26),
                        Text('Vue financière', style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: authInk)),
                        Text('Résumé des achats de votes confirmés.',
                            style: GoogleFonts.nunito(fontSize: 12, color: authMuted)),
                        const SizedBox(height: 14),
                        StreamBuilder<List<VoteOrder>>(
                          stream: VoteService.instance.watchCampaignOrders(campaignId),
                          builder: (context, orderSnap) {
                            final orders = (orderSnap.data ?? const <VoteOrder>[])
                                .where((o) => o.status == VoteOrderStatus.confirmed)
                                .toList();
                            final gross = orders.fold<num>(0, (sum, o) => sum + o.totalAmount);
                            final commission = gross * _platformCommissionRate;
                            final net = gross - commission;
                            final votesSold = orders.fold<int>(0, (sum, o) => sum + o.quantity);
                            return _FinancialGrid(gross: gross, net: net, commission: commission, votesSold: votesSold);
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
}

class _CoverHeader extends StatelessWidget {
  final VoteCampaign campaign;

  const _CoverHeader({required this.campaign});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: authInk,
            image: campaign.coverImageUrl != null
                ? DecorationImage(image: NetworkImage(campaign.coverImageUrl!), fit: BoxFit.cover)
                : null,
          ),
          child: campaign.coverImageUrl == null
              ? const Center(child: Icon(Icons.emoji_events_outlined, size: 48, color: Colors.white70))
              : null,
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
  final VoteCampaignStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      VoteCampaignStatus.draft => ('Brouillon', authMuted),
      VoteCampaignStatus.active => ('Actif', const Color(0xFF1E9E6B)),
      VoteCampaignStatus.ended => ('Terminé', authMuted),
      VoteCampaignStatus.cancelled => ('Annulé', authPrimary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final bool highlighted;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? authPrimary : (highlighted ? const Color(0xFF1E9E6B) : authInk);
    return Material(
      color: highlighted ? color.withOpacity(0.10) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: highlighted ? color : authBorder)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinancialGrid extends StatelessWidget {
  final num gross;
  final num net;
  final num commission;
  final int votesSold;

  const _FinancialGrid({required this.gross, required this.net, required this.commission, required this.votesSold});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern('fr_FR');
    final items = [
      ('Recettes brutes', '${fmt.format(gross)} XAF'),
      ('Net organisation', '${fmt.format(net)} XAF'),
      ('Commission plateforme', '${fmt.format(commission)} XAF'),
      ('Votes payés', '$votesSold'),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.1,
      children: items
          .map((i) => Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(border: Border.all(color: authBorder), borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(i.$1.toUpperCase(), style: GoogleFonts.nunito(fontSize: 9.5, fontWeight: FontWeight.w700, color: authMuted, letterSpacing: 0.4)),
                    const SizedBox(height: 4),
                    Text(i.$2, style: GoogleFonts.nunito(fontSize: 15.5, fontWeight: FontWeight.w800, color: authInk)),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
