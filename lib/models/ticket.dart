import 'package:cloud_firestore/cloud_firestore.dart';

enum TicketStatus { valid, used, cancelled }

TicketStatus _ticketStatusFromString(String? raw) {
  switch (raw) {
    case 'used':
      return TicketStatus.used;
    case 'cancelled':
      return TicketStatus.cancelled;
    default:
      return TicketStatus.valid;
  }
}

String _ticketStatusToString(TicketStatus status) {
  switch (status) {
    case TicketStatus.used:
      return 'used';
    case TicketStatus.cancelled:
      return 'cancelled';
    case TicketStatus.valid:
      return 'valid';
  }
}

/// Un billet individuel, généré à la confirmation d'une [Order] (un par
/// unité achetée). Stocké dans Firestore, collection `tickets`. Le
/// [code] sert de contenu au QR code imprimé sur le PDF et scanné à
/// l'entrée.
class Ticket {
  final String id;
  final String orderId;
  final String eventId;
  final String eventTitle;
  final String? eventCoverImageUrl;
  final String venue;
  final String city;
  final DateTime? seanceStart;
  final String? seanceName;

  final String ticketTypeId;
  final String ticketTypeName;
  final num price;

  final String buyerId;
  final String buyerName;

  final String code;
  final TicketStatus status;
  final DateTime? checkedInAt;
  final DateTime? createdAt;

  const Ticket({
    required this.id,
    required this.orderId,
    required this.eventId,
    required this.eventTitle,
    this.eventCoverImageUrl,
    this.venue = '',
    this.city = '',
    this.seanceStart,
    this.seanceName,
    required this.ticketTypeId,
    required this.ticketTypeName,
    required this.price,
    required this.buyerId,
    required this.buyerName,
    required this.code,
    this.status = TicketStatus.valid,
    this.checkedInAt,
    this.createdAt,
  });

  factory Ticket.fromMap(String id, Map<String, dynamic> map) {
    final rawCreatedAt = map['createdAt'];
    final rawCheckedInAt = map['checkedInAt'];
    final rawSeanceStart = map['seanceStart'];
    return Ticket(
      id: id,
      orderId: map['orderId'] as String? ?? '',
      eventId: map['eventId'] as String? ?? '',
      eventTitle: map['eventTitle'] as String? ?? '',
      eventCoverImageUrl: map['eventCoverImageUrl'] as String?,
      venue: map['venue'] as String? ?? '',
      city: map['city'] as String? ?? '',
      seanceStart:
          rawSeanceStart is Timestamp ? rawSeanceStart.toDate() : null,
      seanceName: map['seanceName'] as String?,
      ticketTypeId: map['ticketTypeId'] as String? ?? '',
      ticketTypeName: map['ticketTypeName'] as String? ?? '',
      price: map['price'] as num? ?? 0,
      buyerId: map['buyerId'] as String? ?? '',
      buyerName: map['buyerName'] as String? ?? '',
      code: map['code'] as String? ?? id,
      status: _ticketStatusFromString(map['status'] as String?),
      checkedInAt:
          rawCheckedInAt is Timestamp ? rawCheckedInAt.toDate() : null,
      createdAt: rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'eventId': eventId,
      'eventTitle': eventTitle,
      'eventCoverImageUrl': eventCoverImageUrl,
      'venue': venue,
      'city': city,
      'seanceStart': seanceStart == null ? null : Timestamp.fromDate(seanceStart!),
      'seanceName': seanceName,
      'ticketTypeId': ticketTypeId,
      'ticketTypeName': ticketTypeName,
      'price': price,
      'buyerId': buyerId,
      'buyerName': buyerName,
      'code': code,
      'status': _ticketStatusToString(status),
      'checkedInAt': null,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
