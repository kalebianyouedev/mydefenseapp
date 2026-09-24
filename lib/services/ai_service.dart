import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:http/http.dart' as http;

import '../models/event.dart';
import '../models/vote_campaign.dart';
import 'event_service.dart';
import 'vote_service.dart';

/// Une recommandation renvoyée par l'assistant : un événement existant
/// (vérifié côté app) et la raison pour laquelle il correspond.
class EventRecommendation {
  final Event event;
  final num? minPrice;
  final String reason;

  const EventRecommendation({
    required this.event,
    required this.minPrice,
    required this.reason,
  });
}

class CampaignRecommendation {
  final VoteCampaign campaign;
  final String reason;

  const CampaignRecommendation({required this.campaign, required this.reason});
}

/// Réponse de l'assistant : un message, éventuellement un texte rédigé
/// (caption, annonce…) et des événements / campagnes de vote vérifiés.
class AssistantAnswer {
  final String message;
  final String text;
  final List<EventRecommendation> events;
  final List<CampaignRecommendation> campaigns;

  const AssistantAnswer({
    required this.message,
    required this.text,
    required this.events,
    required this.campaigns,
  });
}

/// Assistant IA (Gemini). Deux modes :
/// - avec --dart-define=GEMINI_API_KEY=... : appel direct à l'API Gemini
///   (Google AI Studio), pour les tests ;
/// - sans clé : via Firebase AI Logic, protégé par App Check (production).
///
/// - Organisateurs : rédaction de descriptions (organisation, événement)
///   et de bios de candidats.
/// - Utilisateurs : recommandation d'événements selon budget, ville, envies.
class AiService {
  AiService._();
  static final AiService instance = AiService._();

  /// Modèles essayés dans l'ordre : si le premier est saturé (503) ou
  /// hors quota (429), on passe au suivant.
  static const _models = ['gemini-3.7-flash', 'gemini-3.5-flash-lite'];
  static const _timeout = Duration(seconds: 45);

  /// Clé Google AI Studio, passée au lancement avec
  /// --dart-define=GEMINI_API_KEY=... (jamais dans le code). Réservé aux
  /// tests : la clé reste extractable de l'APK. Sans clé, les appels
  /// passent par Firebase AI Logic (protégé par App Check).
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  /// Nombre max d'événements envoyés à l'IA pour une recommandation.
  static const _maxCandidates = 40;

  /// Nombre max de campagnes de vote envoyées à l'IA.
  static const _maxCampaigns = 10;

  /// Appelle Gemini et renvoie le texte produit. [jsonSchema] (JSON
  /// Schema) force une réponse JSON conforme.
  Future<String> _generate({
    required String system,
    required String prompt,
    required double temperature,
    Map<String, Object?>? jsonSchema,
  }) async {
    Object? lastError;
    for (final model in _models) {
      try {
        final text = _apiKey.isNotEmpty
            ? await _generateWithApiKey(
                model, system, prompt, temperature, jsonSchema)
            : await _generateWithFirebase(
                model, system, prompt, temperature, jsonSchema);
        if (text.trim().isEmpty) {
          throw StateError("L'IA n'a pas pu répondre. Réessayez.");
        }
        return text.trim();
      } on _Overloaded catch (e) {
        lastError = e;
      } on QuotaExceeded catch (e) {
        lastError = e;
      } on ServerException catch (e) {
        lastError = e;
      }
    }
    throw lastError ??
        StateError("L'IA est très sollicitée en ce moment. Réessayez.");
  }

  Future<String> _generateWithApiKey(
    String model,
    String system,
    String prompt,
    double temperature,
    Map<String, Object?>? jsonSchema,
  ) async {
    final response = await http
        .post(
          Uri.https('generativelanguage.googleapis.com',
              '/v1beta/models/$model:generateContent'),
          headers: {
            'x-goog-api-key': _apiKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'systemInstruction': {
              'parts': [
                {'text': system},
              ],
            },
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': prompt},
                ],
              },
            ],
            'generationConfig': {
              'temperature': temperature,
              if (jsonSchema != null) ...{
                'responseMimeType': 'application/json',
                'responseJsonSchema': jsonSchema,
              },
            },
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 503 || response.statusCode == 429) {
      throw _Overloaded('Gemini ${response.statusCode} ($model)');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200) {
      throw Exception(
          'Gemini ${response.statusCode} : ${data['error']?['message']}');
    }
    final parts = data['candidates']?[0]?['content']?['parts'] as List?;
    return [
      for (final part in parts ?? const [])
        if (part is Map && part['text'] is String && part['thought'] != true)
          part['text'] as String,
    ].join();
  }

  Future<String> _generateWithFirebase(
    String model,
    String system,
    String prompt,
    double temperature,
    Map<String, Object?>? jsonSchema,
  ) async {
    // Le SDK joint automatiquement le jeton App Check (activé dans
    // main.dart) : Firebase AI Logic refuse les requêtes sans jeton valide.
    final response = await FirebaseAI.googleAI()
        .generativeModel(
          model: model,
          systemInstruction: Content.system(system),
          generationConfig: GenerationConfig(
            temperature: temperature,
            responseMimeType: jsonSchema == null ? null : 'application/json',
            responseJsonSchema: jsonSchema,
          ),
        )
        .generateContent([Content.text(prompt)]).timeout(_timeout);
    return response.text ?? '';
  }

  static const _writerSystem =
      'Tu es un rédacteur pour une application camerounaise de billetterie '
      "et d'événements. Tu écris dans la langue du brouillon fourni "
      '(français ou anglais) ; sans brouillon, en français. Ton '
      'chaleureux et professionnel. Réponds uniquement avec le texte '
      'final : pas de titre, pas de guillemets, pas de markdown, pas de '
      "liste. N'invente aucun fait précis (dates, prix, récompenses, "
      'chiffres) absent des informations fournies.';

  Future<String> _write(String prompt) async {
    final text = await _generate(
        system: _writerSystem, prompt: prompt, temperature: 0.8);
    // Les champs texte n'affichent pas le Markdown : on retire le gras.
    return text.replaceAll('**', '').replaceAll('__', '');
  }

  /// Si [existing] est rempli, il sert de brouillon à améliorer.
  String _draftPart(String existing) => existing.trim().isEmpty
      ? ''
      : '\nBrouillon actuel à améliorer (garde ses informations) :\n'
          '${existing.trim()}';

  /// Consignes libres de l'organisateur (ton, infos à mentionner, format
  /// réseaux sociaux…). Elles priment sur la longueur et le style par défaut.
  String _instructionsPart(String instructions) => instructions.trim().isEmpty
      ? ''
      : "\nConsignes de l'organisateur (à respecter en priorité, y compris "
          'la langue, la longueur, le ton, les emojis ou hashtags demandés) :\n'
          '${instructions.trim()}';

  // ---------------------------------------------------------------------
  // Organisateurs
  // ---------------------------------------------------------------------

  Future<String> generateOrganisationDescription({
    required String name,
    String existing = '',
    String instructions = '',
  }) {
    return _write(
      "Rédige la description d'une organisation (80 à 120 mots) qui "
      'organise des événements.\n'
      'Nom : $name${_draftPart(existing)}${_instructionsPart(instructions)}',
    );
  }

  Future<String> generateEventDescription({
    required String title,
    String venue = '',
    String city = '',
    String existing = '',
    String instructions = '',
  }) {
    return _write(
      "Rédige la description publique d'un événement (100 à 150 mots), "
      'engageante, qui donne envie de réserver.\n'
      'Titre : $title\n'
      '${venue.trim().isEmpty ? '' : 'Lieu : $venue\n'}'
      '${city.trim().isEmpty ? '' : 'Ville : $city\n'}'
      '${_draftPart(existing)}${_instructionsPart(instructions)}',
    );
  }

  Future<String> generateVoteCampaignDescription({
    required String title,
    String organisationName = '',
    String existing = '',
    String instructions = '',
  }) {
    return _write(
      "Rédige la description publique d'une campagne de vote en ligne "
      "(80 à 130 mots) : présente l'enjeu du concours, explique que le "
      'public soutient son candidat préféré en achetant des votes par '
      'Mobile Money, et donne envie de participer.\n'
      'Titre : $title\n'
      '${organisationName.trim().isEmpty ? '' : 'Organisateur : $organisationName\n'}'
      '${_draftPart(existing)}${_instructionsPart(instructions)}',
    );
  }

  Future<String> generateCandidateBio({
    required String name,
    String shortDescription = '',
    String existing = '',
    String instructions = '',
  }) {
    return _write(
      "Rédige la bio d'un candidat à un vote public (60 à 100 mots), à la "
      'troisième personne, valorisante mais factuelle, qui donne envie de '
      'voter pour lui ou elle.\n'
      'Nom : $name\n'
      '${shortDescription.trim().isEmpty ? '' : 'Présentation : $shortDescription\n'}'
      '${_draftPart(existing)}${_instructionsPart(instructions)}',
    );
  }

  // ---------------------------------------------------------------------
  // Assistant : événements, votes en ligne, rédaction de textes
  // ---------------------------------------------------------------------

  /// Répond à un message libre de l'utilisateur :
  /// - recommande des événements (budget, ville, date, envies) ;
  /// - répond aux questions sur les votes en ligne (campagnes ouvertes,
  ///   prix du vote, classement, comment voter) ;
  /// - rédige des textes à la demande (légendes/captions de réseaux
  ///   sociaux, annonces, descriptions) pour les organisateurs.
  /// Seuls des événements et campagnes réellement présents dans Firestore
  /// peuvent être proposés : les identifiants renvoyés par l'IA sont
  /// vérifiés.
  Future<AssistantAnswer> ask(String request) async {
    final now = DateTime.now();
    final loaded = await Future.wait([
      _loadEvents(now),
      _loadCampaigns(),
    ]);
    final events = loaded[0] as _EventsCatalogue;
    final campaigns = loaded[1] as _CampaignsCatalogue;

    final raw = await _generate(
      temperature: 0.4,
      jsonSchema: const {
        'type': 'object',
        'properties': {
          'langue': {
            'type': 'string',
            'enum': ['fr', 'en'],
            'description': "Langue du message de l'utilisateur.",
          },
          'message': {
            'type': 'string',
            'description': "Réponse à l'utilisateur (1 à 4 phrases), ou "
                'explication pratique (ex. comment voter).',
          },
          'texte': {
            'type': 'string',
            'description': 'Texte rédigé à la demande (caption, annonce, '
                'description), prêt à copier. Chaîne vide sinon.',
          },
          'evenements': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'id': {'type': 'string'},
                'raison': {'type': 'string'},
              },
              'required': ['id', 'raison'],
            },
          },
          'campagnes': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'id': {'type': 'string'},
                'raison': {'type': 'string'},
              },
              'required': ['id', 'raison'],
            },
          },
        },
        'required': [
          'langue',
          'message',
          'texte',
          'evenements',
          'campagnes',
        ],
      },
      system: 'You are the assistant of a Cameroonian app for events, '
          'ticketing and online voting (contests, Miss/Mister elections, '
          'awards). You help both the public and event organisers.\n\n'
          'LANGUAGE: first set "langue" to the language of the user message '
          '("fr" or "en"). Then write "message", "texte" and every "raison" '
          'ONLY in that language, even though the catalogue data is in '
          'French. Only use another language if the user explicitly asks '
          'for it (e.g. "write it in English").\n\n'
          'EVENTS: recommend up to 5 events ONLY from the "evenements" '
          'catalogue, using their exact "id", in "evenements". Strictly '
          'respect the budget (prixMinXAF = cheapest ticket; null = unknown '
          'price, avoid it when a budget is given) and the city when given.'
          '\n\n'
          'ONLINE VOTING: open campaigns are in the "campagnes" catalogue '
          '(categories, price per vote in XAF, candidate ranking with vote '
          'counts). Answer concretely in "message": name the leading '
          'candidates with their number and vote count, the price per vote, '
          'the voting deadline. Put the relevant campaigns in "campagnes" '
          'with their exact "id". How to vote in the app: open the campaign, '
          'pick the category then the candidate, tap "Voter pour…", choose '
          'the number of votes, pay with Orange Money or MTN Mobile Money, '
          'then confirm the payment on your phone. Each vote costs the '
          "category's price. Never invent a campaign, candidate or number."
          '\n\n'
          'WRITING (organisers): when asked to write a text (Instagram, '
          'Facebook, TikTok or WhatsApp caption, announcement, description, '
          'call to vote…), put the full ready-to-post text in "texte" and a '
          'short sentence in "message". Adapt the format to the platform '
          '(hook, relevant emojis and hashtags for social media). Use the '
          'catalogue details when the text is about an existing event or '
          'campaign; never invent dates, prices or places. Otherwise '
          '"texte" is an empty string.\n\n'
          'If nothing matches, leave the lists empty and kindly explain it '
          'in "message", suggesting the closest alternative if any. For an '
          'off-topic question, answer briefly and steer back to what you '
          'can do.',
      prompt: "Date d'aujourd'hui : ${now.toIso8601String()}\n"
          'Catalogue evenements : ${jsonEncode(events.json)}\n'
          'Catalogue campagnes : ${jsonEncode(campaigns.json)}\n\n'
          "Message de l'utilisateur : $request\n\n"
          'IMPORTANT: write "message", "texte" and every "raison" in the '
          'same language as the user message above (English message → '
          'English answer, French message → French answer), unless the user '
          'explicitly asks for another language.',
    );

    final data = jsonDecode(raw) as Map<String, dynamic>;
    final eventRecs = <EventRecommendation>[];
    for (final item in (data['evenements'] as List? ?? const [])) {
      if (item is! Map) continue;
      final event = events.byId[item['id']];
      if (event == null) continue; // id inventé par l'IA : ignoré
      eventRecs.add(EventRecommendation(
        event: event,
        minPrice: events.priceById[event.id],
        reason: item['raison'] as String? ?? '',
      ));
    }
    final campaignRecs = <CampaignRecommendation>[];
    for (final item in (data['campagnes'] as List? ?? const [])) {
      if (item is! Map) continue;
      final campaign = campaigns.byId[item['id']];
      if (campaign == null) continue;
      campaignRecs.add(CampaignRecommendation(
        campaign: campaign,
        reason: item['raison'] as String? ?? '',
      ));
    }
    return AssistantAnswer(
      message: data['message'] as String? ?? '',
      text: (data['texte'] as String? ?? '')
          .replaceAll('**', '')
          .replaceAll('__', '')
          .trim(),
      events: eventRecs,
      campaigns: campaignRecs,
    );
  }

  Future<_EventsCatalogue> _loadEvents(DateTime now) async {
    List<Event> events;
    try {
      events = (await EventService.instance.fetchPublished())
          .where((e) => e.seances.any((s) => s.end.isAfter(now)))
          .take(_maxCandidates)
          .toList();
    } catch (_) {
      events = const [];
    }
    final prices = await Future.wait(
      events.map((e) => e.isFree
          ? Future<num?>.value(0)
          : EventService.instance.fetchMinPrice(e.id)),
    );
    final priceById = {
      for (var i = 0; i < events.length; i++) events[i].id: prices[i],
    };
    return _EventsCatalogue(
      byId: {for (final e in events) e.id: e},
      priceById: priceById,
      json: [
        for (final e in events)
          {
            'id': e.id,
            'titre': e.title,
            'organisateur': e.organisationName,
            'categorie': e.category.label,
            'ville': e.city,
            'lieu': e.venue,
            'prixMinXAF': priceById[e.id],
            'seances': [
              for (final s in e.seances.where((s) => s.end.isAfter(now)))
                s.start.toIso8601String(),
            ],
            'description': _truncate(e.description, 300),
          },
      ],
    );
  }

  Future<_CampaignsCatalogue> _loadCampaigns() async {
    List<VoteCampaign> campaigns;
    try {
      campaigns = (await VoteService.instance.fetchActive())
          .where((c) => c.isOpenForVoting)
          .take(_maxCampaigns)
          .toList();
    } catch (_) {
      campaigns = const [];
    }
    final details = await Future.wait(campaigns.map((c) async {
      try {
        final categories = await VoteService.instance.fetchCategories(c.id);
        return Future.wait(categories.map((cat) async {
          final top = await VoteService.instance
              .fetchTopCandidates(c.id, cat.id);
          return {
            'categorie': cat.title,
            'prixParVoteXAF': cat.pricePerVote,
            'classement': [
              for (final cand in top)
                {
                  'numero': cand.number,
                  'nom': cand.name,
                  'votes': cand.voteCount,
                  if (cand.description.isNotEmpty)
                    'presentation': _truncate(cand.description, 80),
                },
            ],
          };
        }));
      } catch (_) {
        return const <Map<String, Object?>>[];
      }
    }));
    return _CampaignsCatalogue(
      byId: {for (final c in campaigns) c.id: c},
      json: [
        for (var i = 0; i < campaigns.length; i++)
          {
            'id': campaigns[i].id,
            'titre': campaigns[i].title,
            'organisateur': campaigns[i].organisationName,
            'description': _truncate(campaigns[i].description, 200),
            if (campaigns[i].endsAt != null)
              'finDuVote': campaigns[i].endsAt!.toIso8601String(),
            'categories': details[i],
          },
      ],
    );
  }

  static String _truncate(String text, int max) =>
      text.length > max ? '${text.substring(0, max)}…' : text;
}

class _EventsCatalogue {
  final Map<String, Event> byId;
  final Map<String, num?> priceById;
  final List<Map<String, Object?>> json;

  const _EventsCatalogue({
    required this.byId,
    required this.priceById,
    required this.json,
  });
}

class _CampaignsCatalogue {
  final Map<String, VoteCampaign> byId;
  final List<Map<String, Object?>> json;

  const _CampaignsCatalogue({required this.byId, required this.json});
}

/// Modèle saturé ou quota atteint : on essaie le modèle suivant.
class _Overloaded implements Exception {
  final String message;
  _Overloaded(this.message);

  @override
  String toString() => message;
}
