import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/payment_method.dart';
import '../models/vote_campaign.dart';
import '../models/vote_candidate.dart';
import '../models/vote_category.dart';
import '../services/vote_service.dart';
import '../widgets/auth_widgets.dart'
    show authPrimary, authInk, authMuted, authBorder, showAuthSnack;
import 'vote_order_confirmation_screen.dart';

/// Palette catégorielle validée (voir la skill dataviz) : ordre fixe,
/// distincte en daltonisme. Assignée par le numéro (stable) du candidat,
/// jamais par son rang courant, pour que sa couleur ne change pas quand
/// le classement bouge.
const _categoricalPalette = [
  Color(0xFF2A78D6), // bleu
  Color(0xFFEB6834), // orange
  Color(0xFF1BAF7A), // aqua
  Color(0xFFEDA100), // jaune
  Color(0xFFE87BA4), // magenta
  Color(0xFF008300), // vert
  Color(0xFF4A3AA7), // violet
  Color(0xFFE34948), // rouge
];

/// Couleur stable par candidat : assignée dans l'ordre de son numéro
/// (fixe depuis sa création), jamais dans l'ordre du classement courant,
/// pour que sa couleur reste la même partout (camembert, classement,
/// carte) même quand le classement bouge.
Map<String, Color> _stableCandidateColors(List<VoteCandidate> candidates) {
  final byNumber = [...candidates]..sort((a, b) => a.number.compareTo(b.number));
  return {
    for (var i = 0; i < byNumber.length; i++)
      byNumber[i].id: _categoricalPalette[i % _categoricalPalette.length],
  };
}

/// Page publique d'une campagne de vote : description, catégories et
/// candidats, avec achat de votes par Mobile Money. Ouverte depuis le
/// fil public des votes ou depuis le tableau de bord de l'organisation
/// (aperçu).
class PublicVoteCampaignScreen extends StatelessWidget {
  final VoteCampaign campaign;

  const PublicVoteCampaignScreen({super.key, required this.campaign});

  Future<void> _openVoteSheet(BuildContext context, VoteCategory category, VoteCandidate candidate) async {
    final orderId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _VoteSheet(campaign: campaign, category: category, candidate: candidate),
    );
    if (orderId != null && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => VoteOrderConfirmationScreen(orderId: orderId)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Cover(campaign: campaign)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(campaign.organisationName.toUpperCase(),
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: authPrimary, letterSpacing: 0.6)),
                    const SizedBox(height: 4),
                    Text(campaign.title, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: authInk)),
                    if (campaign.description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(campaign.description, style: GoogleFonts.poppins(fontSize: 13.5, color: authInk, height: 1.5)),
                    ],
                    if (!campaign.isOpenForVoting) ...[
                      const SizedBox(height: 16),
                      _StatusBanner(campaign: campaign),
                    ],
                    const SizedBox(height: 22),
                    StreamBuilder<List<VoteCategory>>(
                      stream: VoteService.instance.watchCategories(campaign.id),
                      builder: (context, snapshot) {
                        final categories = snapshot.data ?? const <VoteCategory>[];
                        if (categories.isEmpty) {
                          return Text('Aucune catégorie pour le moment.',
                              style: GoogleFonts.poppins(fontSize: 13, color: authMuted));
                        }
                        return Column(
                          children: categories
                              .map((c) => _CategorySection(
                                    campaign: campaign,
                                    category: c,
                                    onVote: (candidate) => _openVoteSheet(context, c, candidate),
                                  ))
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  final VoteCampaign campaign;

  const _Cover({required this.campaign});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 220,
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

class _StatusBanner extends StatelessWidget {
  final VoteCampaign campaign;

  const _StatusBanner({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final message = switch (campaign.status) {
      VoteCampaignStatus.draft => 'Le vote n\'est pas encore ouvert.',
      VoteCampaignStatus.ended => 'Le vote est terminé.',
      VoteCampaignStatus.cancelled => 'Cette campagne a été annulée.',
      VoteCampaignStatus.active => campaign.startsAt != null && DateTime.now().isBefore(campaign.startsAt!)
          ? 'Le vote ouvrira le ${DateFormat("d MMMM y 'à' HH'h'mm", 'fr_FR').format(campaign.startsAt!)}.'
          : 'Le vote est terminé.',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: const Color(0xFFF4F4F6), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: authMuted),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: GoogleFonts.poppins(fontSize: 12.5, color: authMuted))),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final VoteCampaign campaign;
  final VoteCategory category;
  final ValueChanged<VoteCandidate> onVote;

  const _CategorySection({required this.campaign, required this.category, required this.onVote});

  void _openDetail(BuildContext context, VoteCandidate candidate, int totalVotes) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CandidateDetailSheet(
        candidate: candidate,
        totalVotes: totalVotes,
        canVote: campaign.isOpenForVoting,
        onVote: () {
          Navigator.of(context).pop();
          onVote(candidate);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern('fr_FR');
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(category.title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: authInk)),
              ),
              Text('${fmt.format(category.pricePerVote)} XAF / vote',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: authMuted)),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<VoteCandidate>>(
            stream: VoteService.instance.watchCandidates(campaign.id, category.id),
            builder: (context, snapshot) {
              final candidates = snapshot.data ?? const <VoteCandidate>[];
              if (candidates.isEmpty) {
                return Text('Aucun candidat pour le moment.', style: GoogleFonts.poppins(fontSize: 12.5, color: authMuted));
              }
              final totalVotes = candidates.fold<int>(0, (sum, c) => sum + c.voteCount);
              final colors = _stableCandidateColors(candidates);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _CategoryStats(candidates: candidates, totalVotes: totalVotes),
                  ),
                  ...candidates.asMap().entries.map((entry) => _CandidateCard(
                        candidate: entry.value,
                        color: colors[entry.value.id]!,
                        isLeader: entry.key == 0 && totalVotes > 0,
                        percentage: totalVotes == 0 ? 0 : entry.value.voteCount / totalVotes * 100,
                        canVote: campaign.isOpenForVoting,
                        onVote: () => onVote(entry.value),
                        onTapProfile: () => _openDetail(context, entry.value, totalVotes),
                      )),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Statistiques d'une catégorie : répartition des votes en camembert
/// (une couleur stable par candidat, jamais par rang) et classement
/// numéroté juste en dessous.
class _CategoryStats extends StatelessWidget {
  final List<VoteCandidate> candidates;
  final int totalVotes;

  const _CategoryStats({required this.candidates, required this.totalVotes});

  @override
  Widget build(BuildContext context) {
    final colors = _stableCandidateColors(candidates);

    if (totalVotes == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: const Color(0xFFF7F8FA), borderRadius: BorderRadius.circular(18)),
        child: Text('Aucun vote pour le moment dans cette catégorie.',
            style: GoogleFonts.poppins(fontSize: 12.5, color: authMuted)),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: authBorder), borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Répartition des votes', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: authInk)),
          const SizedBox(height: 14),
          SizedBox(
            height: 140,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 34,
                sections: candidates.map((c) {
                  final pct = c.voteCount / totalVotes * 100;
                  return PieChartSectionData(
                    value: c.voteCount.toDouble(),
                    color: colors[c.id],
                    radius: 36,
                    showTitle: pct >= 8,
                    title: '${pct.toStringAsFixed(0)}%',
                    titleStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Classement', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: authInk)),
          const SizedBox(height: 10),
          ...candidates.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final candidate = entry.value;
            final pct = candidate.voteCount / totalVotes * 100;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  _RankBadge(rank: rank),
                  const SizedBox(width: 10),
                  Container(width: 9, height: 9, decoration: BoxDecoration(color: colors[candidate.id], shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(candidate.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: authInk)),
                  ),
                  Text('${candidate.voteCount} · ${pct.toStringAsFixed(0)}%',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: authMuted)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;

  const _RankBadge({required this.rank});

  static const _medalColors = {
    1: Color(0xFFC9971A),
    2: Color(0xFF9AA0A6),
    3: Color(0xFFB56A3C),
  };

  @override
  Widget build(BuildContext context) {
    final color = _medalColors[rank] ?? authMuted;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(color: color.withOpacity(rank <= 3 ? 1 : 0.12), shape: BoxShape.circle),
      child: Center(
        child: Text('$rank',
            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: rank <= 3 ? Colors.white : authMuted)),
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  final VoteCandidate candidate;
  final Color color;
  final bool isLeader;
  final double percentage;
  final bool canVote;
  final VoidCallback onVote;
  final VoidCallback onTapProfile;

  const _CandidateCard({
    required this.candidate,
    required this.color,
    required this.isLeader,
    required this.percentage,
    required this.canVote,
    required this.onVote,
    required this.onTapProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: isLeader ? const Color(0xFFC9971A) : authBorder, width: isLeader ? 1.4 : 1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onTapProfile,
            behavior: HitTestBehavior.opaque,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: 92,
                        height: 110,
                        child: candidate.photoUrl != null
                            ? Image.network(
                                candidate.photoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const ColoredBox(
                                  color: Color(0xFFF4F4F6),
                                  child: Icon(Icons.person_outline, color: authMuted, size: 34),
                                ),
                              )
                            : const ColoredBox(
                                color: Color(0xFFF4F4F6),
                                child: Icon(Icons.person_outline, color: authMuted, size: 34),
                              ),
                      ),
                    ),
                    Positioned(
                      bottom: -6,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: authInk, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white, width: 1.5)),
                        child: Text('N°${candidate.number}', style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(candidate.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: authInk)),
                          ),
                          if (isLeader) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.emoji_events, size: 15, color: Color(0xFFC9971A)),
                          ],
                        ],
                      ),
                      if (candidate.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(candidate.description, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(fontSize: 12, color: authMuted)),
                      ],
                      if (candidate.bio.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(candidate.bio, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(fontSize: 11.5, color: authMuted, height: 1.3)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFF4F4F6),
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('${percentage.toStringAsFixed(0)}%',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: authInk)),
            ],
          ),
          const SizedBox(height: 4),
          Text('${candidate.voteCount} vote${candidate.voteCount > 1 ? 's' : ''}',
              style: GoogleFonts.poppins(fontSize: 11, color: authMuted)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canVote ? onVote : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: authPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Voter pour ${candidate.name}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fiche détaillée d'un candidat (photo, numéro, description, bio
/// complète), ouverte en tapant sur sa carte.
class _CandidateDetailSheet extends StatelessWidget {
  final VoteCandidate candidate;
  final int totalVotes;
  final bool canVote;
  final VoidCallback onVote;

  const _CandidateDetailSheet({
    required this.candidate,
    required this.totalVotes,
    required this.canVote,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = totalVotes == 0 ? 0.0 : candidate.voteCount / totalVotes * 100;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: const Color(0xFFF4F4F6),
            backgroundImage: candidate.photoUrl != null ? NetworkImage(candidate.photoUrl!) : null,
            child: candidate.photoUrl == null ? const Icon(Icons.person_outline, color: authMuted, size: 40) : null,
          ),
          const SizedBox(height: 14),
          Text('Candidat N°${candidate.number}', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: authPrimary)),
          const SizedBox(height: 4),
          Text(candidate.name, style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w700, color: authInk)),
          if (candidate.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(candidate.description, style: GoogleFonts.poppins(fontSize: 13, color: authMuted)),
          ],
          const SizedBox(height: 14),
          Text('${candidate.voteCount} vote${candidate.voteCount > 1 ? 's' : ''} · ${percentage.toStringAsFixed(0)}% des votes',
              style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: authInk)),
          if (candidate.bio.isNotEmpty) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(candidate.bio, style: GoogleFonts.poppins(fontSize: 13.5, color: authInk, height: 1.5)),
            ),
          ],
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: canVote ? onVote : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: authPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text('Voter pour ${candidate.name}', style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoteSheet extends StatefulWidget {
  final VoteCampaign campaign;
  final VoteCategory category;
  final VoteCandidate candidate;

  const _VoteSheet({required this.campaign, required this.category, required this.candidate});

  @override
  State<_VoteSheet> createState() => _VoteSheetState();
}

class _VoteSheetState extends State<_VoteSheet> {
  final _phoneCtrl = TextEditingController();
  PaymentMethod _method = PaymentMethod.orangeMoney;
  int _quantity = 1;
  bool _submitting = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_phoneCtrl.text.trim().length < 8) {
      showAuthSnack(context, 'Entrez un numéro de téléphone valide.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final orderId = await VoteService.instance.createVoteOrder(
        campaign: widget.campaign,
        category: widget.category,
        candidate: widget.candidate,
        quantity: _quantity,
        paymentMethod: _method,
        paymentPhone: _phoneCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(orderId);
    } catch (e) {
      if (mounted) showAuthSnack(context, e is StateError ? e.message : 'Échec de la commande.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern('fr_FR');
    final total = widget.category.pricePerVote * _quantity;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Voter pour ${widget.candidate.name}', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: authInk)),
          const SizedBox(height: 4),
          Text('${fmt.format(widget.category.pricePerVote)} XAF par vote', style: GoogleFonts.poppins(fontSize: 12.5, color: authMuted)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Nombre de votes', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: authInk)),
              Row(
                children: [
                  _stepperButton(Icons.remove, _quantity > 1 ? () => setState(() => _quantity--) : null),
                  SizedBox(width: 36, child: Text('$_quantity', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700))),
                  _stepperButton(Icons.add, () => setState(() => _quantity++)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Moyen de paiement', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: authInk)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MethodChip(
                  label: 'Orange Money',
                  color: const Color(0xFFFF7900),
                  selected: _method == PaymentMethod.orangeMoney,
                  onTap: () => setState(() => _method = PaymentMethod.orangeMoney),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MethodChip(
                  label: 'MTN MoMo',
                  color: const Color(0xFFFFCC00),
                  selected: _method == PaymentMethod.mtnMomo,
                  onTap: () => setState(() => _method = PaymentMethod.mtnMomo),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Numéro ${paymentMethodLabel(_method)}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: authInk)),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.poppins(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Ex. 6XX XX XX XX',
              prefixIcon: const Icon(Icons.phone_outlined, size: 20, color: authMuted),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: authBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: authBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: authPrimary, width: 1.4)),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: authPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _submitting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Text('Payer ${fmt.format(total)} XAF', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
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

class _MethodChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _MethodChip({required this.label, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.10) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : authBorder, width: selected ? 1.6 : 1),
        ),
        child: Column(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: const Icon(Icons.phone_iphone, size: 15, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: authInk)),
          ],
        ),
      ),
    );
  }
}
