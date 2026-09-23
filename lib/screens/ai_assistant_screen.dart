import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/ai_service.dart';
import '../widgets/auth_widgets.dart'
    show authPrimary, authInk, authMuted, authBorder, showAuthSnack;
import 'event_detail_screen.dart';
import 'public_vote_campaign_screen.dart';

/// Un échange de la conversation : la question de l'utilisateur, puis la
/// réponse de l'assistant (null tant qu'elle est en cours).
class _Exchange {
  final String question;
  AssistantAnswer? result;
  String? error;

  _Exchange(this.question);
}

/// Assistant IA : recommande des événements (budget, ville, date, envies),
/// répond aux questions sur les votes en ligne et rédige des textes
/// (captions, annonces) pour les organisateurs.
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  static const _suggestions = [
    'Un concert à Douala ce week-end, 5 000 XAF max',
    'Quels votes sont ouverts et qui est en tête ?',
    'Comment voter pour un candidat ?',
    'Écris une caption Instagram pour annoncer mon événement',
  ];

  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_Exchange> _exchanges = [];
  bool _busy = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _ask(String question) async {
    question = question.trim();
    if (question.isEmpty || _busy) return;
    final exchange = _Exchange(question);
    setState(() {
      _exchanges.add(exchange);
      _busy = true;
      _inputCtrl.clear();
    });
    _scrollToBottom();
    try {
      exchange.result = await AiService.instance.ask(question);
    } catch (e) {
      debugPrint('Assistant IA : $e');
      exchange.error = e is StateError
          ? e.message
          : kDebugMode
              ? "L'assistant est indisponible : $e"
              : "L'assistant est indisponible pour le moment. Réessayez.";
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: authInk,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, size: 18, color: authPrimary),
            const SizedBox(width: 8),
            Text('Assistant IA',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w600, color: authInk)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _exchanges.isEmpty
                  ? _Intro(onSuggestion: _ask, suggestions: _suggestions)
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: _exchanges.length,
                      itemBuilder: (_, i) => _ExchangeView(_exchanges[i]),
                    ),
            ),
            _InputBar(
              controller: _inputCtrl,
              busy: _busy,
              onSend: () => _ask(_inputCtrl.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onSuggestion;

  const _Intro({required this.suggestions, required this.onSuggestion});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      children: [
        const Icon(Icons.auto_awesome, size: 40, color: authPrimary),
        const SizedBox(height: 16),
        Text(
          'Comment puis-je vous aider ?',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
              fontSize: 20, fontWeight: FontWeight.w700, color: authInk),
        ),
        const SizedBox(height: 8),
        Text(
          'Je trouve des événements selon votre ville et votre budget, '
          'je réponds à vos questions sur les votes en ligne, et je rédige '
          'vos captions et annonces. En français ou en anglais.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 13.5, color: authMuted),
        ),
        const SizedBox(height: 24),
        for (final s in suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OutlinedButton(
              onPressed: () => onSuggestion(s),
              style: OutlinedButton.styleFrom(
                foregroundColor: authInk,
                side: const BorderSide(color: authBorder),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(s, style: GoogleFonts.poppins(fontSize: 13.5)),
            ),
          ),
      ],
    );
  }
}

class _ExchangeView extends StatelessWidget {
  final _Exchange exchange;

  const _ExchangeView(this.exchange);

  @override
  Widget build(BuildContext context) {
    final result = exchange.result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 10, left: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: authPrimary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(exchange.question,
                style: GoogleFonts.poppins(fontSize: 13.5, color: Colors.white)),
          ),
        ),
        if (exchange.error != null)
          _AssistantBubble(exchange.error!)
        else if (result == null)
          const Padding(
            padding: EdgeInsets.all(8),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: authPrimary),
            ),
          )
        else ...[
          if (result.message.isNotEmpty) _AssistantBubble(result.message),
          if (result.text.isNotEmpty) _GeneratedTextCard(result.text),
          for (final r in result.events) _RecommendationCard(r),
          for (final c in result.campaigns) _CampaignCard(c),
        ],
      ],
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  final String text;

  const _AssistantBubble(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10, right: 48),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text,
          style: GoogleFonts.poppins(fontSize: 13.5, color: authInk)),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final EventRecommendation recommendation;

  const _RecommendationCard(this.recommendation);

  String _priceLabel() {
    final price = recommendation.minPrice;
    if (recommendation.event.isFree || price == 0) return 'Gratuit';
    if (price == null) return '';
    return 'Dès ${NumberFormat.decimalPattern('fr_FR').format(price)} XAF';
  }

  @override
  Widget build(BuildContext context) {
    final event = recommendation.event;
    final seance = event.primarySeance;
    final subtitle = [
      if (seance != null)
        DateFormat('EEE d MMM · HH:mm', 'fr_FR').format(seance.start),
      if (event.city.isNotEmpty) event.city,
    ].join(' · ');
    final price = _priceLabel();

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: authBorder),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 72,
                height: 72,
                child: event.coverImageUrl != null
                    ? Image.network(event.coverImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const _CoverPlaceholder())
                    : const _CoverPlaceholder(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: authInk)),
                  if (subtitle.isNotEmpty)
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: authMuted)),
                  if (price.isNotEmpty)
                    Text(price,
                        style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: authPrimary)),
                  if (recommendation.reason.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(recommendation.reason,
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: authInk, height: 1.35)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Texte rédigé par l'IA (caption, annonce…), avec un bouton pour le
/// copier et le coller sur les réseaux sociaux.
class _GeneratedTextCard extends StatelessWidget {
  final String text;

  const _GeneratedTextCard(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
      decoration: BoxDecoration(
        border: Border.all(color: authPrimary.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SelectableText(text,
                style: GoogleFonts.poppins(
                    fontSize: 13.5, color: authInk, height: 1.45)),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted) showAuthSnack(context, 'Texte copié.');
              },
              style: TextButton.styleFrom(foregroundColor: authPrimary),
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: Text('Copier',
                  style: GoogleFonts.poppins(
                      fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final CampaignRecommendation recommendation;

  const _CampaignCard(this.recommendation);

  @override
  Widget build(BuildContext context) {
    final campaign = recommendation.campaign;
    final endsAt = campaign.endsAt;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => PublicVoteCampaignScreen(campaign: campaign)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: authBorder),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 72,
                height: 72,
                child: campaign.coverImageUrl != null
                    ? Image.network(campaign.coverImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const _CoverPlaceholder(icon: Icons.how_to_vote))
                    : const _CoverPlaceholder(icon: Icons.how_to_vote),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(campaign.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: authInk)),
                  Text(
                    [
                      campaign.organisationName,
                      if (endsAt != null)
                        "Jusqu'au ${DateFormat('d MMM · HH:mm', 'fr_FR').format(endsAt)}",
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(fontSize: 12, color: authMuted),
                  ),
                  Text('Voter',
                      style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: authPrimary)),
                  if (recommendation.reason.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(recommendation.reason,
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: authInk, height: 1.35)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  final IconData icon;

  const _CoverPlaceholder({this.icon = Icons.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF4F4F6),
      child: Icon(icon, color: authMuted),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.busy,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF4F4F6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: controller,
                enabled: !busy,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: GoogleFonts.poppins(fontSize: 14, color: authInk),
                decoration: InputDecoration(
                  hintText: 'Événement, vote, caption…',
                  hintStyle:
                      GoogleFonts.poppins(fontSize: 13.5, color: authMuted),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton.filled(
              onPressed: busy ? null : onSend,
              style: IconButton.styleFrom(
                backgroundColor: authPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
