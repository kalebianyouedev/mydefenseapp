import 'package:cloud_firestore/cloud_firestore.dart';

enum EventStatus { draft, published, cancelled }

EventStatus _statusFromString(String? raw) {
  switch (raw) {
    case 'published':
      return EventStatus.published;
    case 'cancelled':
      return EventStatus.cancelled;
    default:
      return EventStatus.draft;
  }
}

String _statusToString(EventStatus status) {
  switch (status) {
    case EventStatus.published:
      return 'published';
    case EventStatus.cancelled:
      return 'cancelled';
    case EventStatus.draft:
      return 'draft';
  }
}

/// Une séance (date) d'un événement. Chaque séance a ensuite ses propres
/// types de billets (sous-collection `events/{id}/ticketTypes`).
class Seance {
  final String id;
  final String? name;
  final DateTime start;
  final DateTime end;
  final DateTime? salesEnd;

  const Seance({
    required this.id,
    this.name,
    required this.start,
    required this.end,
    this.salesEnd,
  });

  factory Seance.fromMap(Map<String, dynamic> map) {
    final rawStart = map['start'];
    final rawEnd = map['end'];
    final rawSalesEnd = map['salesEnd'];
    return Seance(
      id: map['id'] as String? ?? '',
      name: (map['name'] as String?)?.trim().isEmpty ?? true
          ? null
          : map['name'] as String,
      start: rawStart is Timestamp ? rawStart.toDate() : DateTime.now(),
      end: rawEnd is Timestamp ? rawEnd.toDate() : DateTime.now(),
      salesEnd: rawSalesEnd is Timestamp ? rawSalesEnd.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'start': Timestamp.fromDate(start),
      'end': Timestamp.fromDate(end),
      'salesEnd': salesEnd == null ? null : Timestamp.fromDate(salesEnd!),
    };
  }
}

/// Événement créé par une organisation. Stocké dans Firestore, collection
/// `events`. Les types de billets vivent dans la sous-collection
/// `events/{id}/ticketTypes` (voir [TicketType]), configurables une fois
/// l'événement créé.
class Event {
  final String id;
  final String organisationId;
  final String organisationName;
  final String? organisationLogoUrl;
  final String ownerId;

  final String title;
  final String description;
  final String venue;
  final String city;

  final String? coverImageUrl;
  final String? videoUrl;
  final List<String> gallery;

  final List<Seance> seances;

  final bool isFree;
  final int? capacity;
  final String? refundPolicy;

  final EventStatus status;
  final int views;
  final int boosts;

  final DateTime? createdAt;
  final DateTime? publishedAt;

  const Event({
    required this.id,
    required this.organisationId,
    required this.organisationName,
    this.organisationLogoUrl,
    required this.ownerId,
    required this.title,
    this.description = '',
    this.venue = '',
    this.city = '',
    this.coverImageUrl,
    this.videoUrl,
    this.gallery = const [],
    this.seances = const [],
    this.isFree = false,
    this.capacity,
    this.refundPolicy,
    this.status = EventStatus.draft,
    this.views = 0,
    this.boosts = 0,
    this.createdAt,
    this.publishedAt,
  });

  /// Première séance à venir (ou la première tout court si toutes sont
  /// passées) : sert d'affichage résumé (ex. sur la page d'accueil).
  Seance? get primarySeance {
    if (seances.isEmpty) return null;
    final now = DateTime.now();
    final upcoming = seances.where((s) => s.end.isAfter(now)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    if (upcoming.isNotEmpty) return upcoming.first;
    final sorted = [...seances]..sort((a, b) => a.start.compareTo(b.start));
    return sorted.first;
  }

  factory Event.fromMap(String id, Map<String, dynamic> map) {
    final rawCreatedAt = map['createdAt'];
    final rawPublishedAt = map['publishedAt'];
    final rawSeances = map['seances'] as List<dynamic>? ?? const [];
    return Event(
      id: id,
      organisationId: map['organisationId'] as String? ?? '',
      organisationName: map['organisationName'] as String? ?? '',
      organisationLogoUrl: map['organisationLogoUrl'] as String?,
      ownerId: map['ownerId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      venue: map['venue'] as String? ?? '',
      city: map['city'] as String? ?? '',
      coverImageUrl: map['coverImageUrl'] as String?,
      videoUrl: map['videoUrl'] as String?,
      gallery: (map['gallery'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      seances: rawSeances
          .map((e) => Seance.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      isFree: map['isFree'] as bool? ?? false,
      capacity: (map['capacity'] as num?)?.toInt(),
      refundPolicy: map['refundPolicy'] as String?,
      status: _statusFromString(map['status'] as String?),
      views: (map['views'] as num?)?.toInt() ?? 0,
      boosts: (map['boosts'] as num?)?.toInt() ?? 0,
      createdAt: rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : null,
      publishedAt:
          rawPublishedAt is Timestamp ? rawPublishedAt.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organisationId': organisationId,
      'organisationName': organisationName,
      'organisationLogoUrl': organisationLogoUrl,
      'ownerId': ownerId,
      'title': title,
      'description': description,
      'venue': venue,
      'city': city,
      'coverImageUrl': coverImageUrl,
      'videoUrl': videoUrl,
      'gallery': gallery,
      'seances': seances.map((s) => s.toMap()).toList(),
      'isFree': isFree,
      'capacity': capacity,
      'refundPolicy': refundPolicy,
      'status': _statusToString(status),
      'views': views,
      'boosts': boosts,
      'createdAt': FieldValue.serverTimestamp(),
      'publishedAt':
          status == EventStatus.published ? FieldValue.serverTimestamp() : null,
    };
  }
}
