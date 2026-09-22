import 'package:cloud_firestore/cloud_firestore.dart';

/// Type de billet (ex. "Standard", "VIP") rattaché à une séance d'un
/// événement. Stocké dans Firestore, sous-collection
/// `events/{eventId}/ticketTypes`.
class TicketType {
  final String id;
  final String eventId;
  final String seanceId;
  final String name;
  final num price;
  final int? quantityTotal;
  final int quantitySold;
  final DateTime? createdAt;

  const TicketType({
    required this.id,
    required this.eventId,
    required this.seanceId,
    required this.name,
    required this.price,
    this.quantityTotal,
    this.quantitySold = 0,
    this.createdAt,
  });

  bool get isSoldOut =>
      quantityTotal != null && quantitySold >= quantityTotal!;

  int? get remaining =>
      quantityTotal == null ? null : quantityTotal! - quantitySold;

  factory TicketType.fromMap(String id, Map<String, dynamic> map) {
    final rawCreatedAt = map['createdAt'];
    return TicketType(
      id: id,
      eventId: map['eventId'] as String? ?? '',
      seanceId: map['seanceId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      price: map['price'] as num? ?? 0,
      quantityTotal: (map['quantityTotal'] as num?)?.toInt(),
      quantitySold: (map['quantitySold'] as num?)?.toInt() ?? 0,
      createdAt: rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'seanceId': seanceId,
      'name': name,
      'price': price,
      'quantityTotal': quantityTotal,
      'quantitySold': quantitySold,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
