import 'package:cloud_firestore/cloud_firestore.dart';

import 'payment_method.dart';

enum OrderStatus { pending, confirmed, cancelled }

OrderStatus _orderStatusFromString(String? raw) {
  switch (raw) {
    case 'confirmed':
      return OrderStatus.confirmed;
    case 'cancelled':
      return OrderStatus.cancelled;
    default:
      return OrderStatus.pending;
  }
}

String _orderStatusToString(OrderStatus status) {
  switch (status) {
    case OrderStatus.confirmed:
      return 'confirmed';
    case OrderStatus.cancelled:
      return 'cancelled';
    case OrderStatus.pending:
      return 'pending';
  }
}

/// Une ligne de commande : un type de billet, pour une séance, en une
/// certaine quantité.
class OrderItem {
  final String ticketTypeId;
  final String ticketTypeName;
  final String seanceId;
  final String seanceName;
  final DateTime? seanceStart;
  final int quantity;
  final num unitPrice;

  const OrderItem({
    required this.ticketTypeId,
    required this.ticketTypeName,
    required this.seanceId,
    required this.seanceName,
    this.seanceStart,
    required this.quantity,
    required this.unitPrice,
  });

  num get subtotal => unitPrice * quantity;

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    final rawSeanceStart = map['seanceStart'];
    return OrderItem(
      ticketTypeId: map['ticketTypeId'] as String? ?? '',
      ticketTypeName: map['ticketTypeName'] as String? ?? '',
      seanceId: map['seanceId'] as String? ?? '',
      seanceName: map['seanceName'] as String? ?? '',
      seanceStart:
          rawSeanceStart is Timestamp ? rawSeanceStart.toDate() : null,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: map['unitPrice'] as num? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ticketTypeId': ticketTypeId,
      'ticketTypeName': ticketTypeName,
      'seanceId': seanceId,
      'seanceName': seanceName,
      'seanceStart': seanceStart == null ? null : Timestamp.fromDate(seanceStart!),
      'quantity': quantity,
      'unitPrice': unitPrice,
    };
  }
}

/// Commande de billets pour un événement, payée par Orange Money ou MTN
/// Mobile Money. Stockée dans Firestore, collection `orders`. À la
/// confirmation, un [Ticket] est généré par unité achetée.
///
/// Nommée `TicketOrder` (et non `Order`) pour ne pas entrer en conflit
/// avec la classe `Order` exportée par `cloud_firestore`.
class TicketOrder {
  final String id;
  final String eventId;
  final String eventTitle;
  final String? eventCoverImageUrl;
  final String eventVenue;
  final String eventCity;

  final String buyerId;
  final String buyerName;

  final List<OrderItem> items;
  final num totalAmount;
  final String currency;

  final PaymentMethod paymentMethod;
  final String paymentPhone;
  final String? promoCode;

  final OrderStatus status;
  final DateTime? createdAt;
  final DateTime? confirmedAt;

  const TicketOrder({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    this.eventCoverImageUrl,
    this.eventVenue = '',
    this.eventCity = '',
    required this.buyerId,
    required this.buyerName,
    required this.items,
    required this.totalAmount,
    this.currency = 'XAF',
    required this.paymentMethod,
    required this.paymentPhone,
    this.promoCode,
    this.status = OrderStatus.pending,
    this.createdAt,
    this.confirmedAt,
  });

  int get ticketCount => items.fold(0, (sum, i) => sum + i.quantity);

  factory TicketOrder.fromMap(String id, Map<String, dynamic> map) {
    final rawCreatedAt = map['createdAt'];
    final rawConfirmedAt = map['confirmedAt'];
    final rawItems = map['items'] as List<dynamic>? ?? const [];
    return TicketOrder(
      id: id,
      eventId: map['eventId'] as String? ?? '',
      eventTitle: map['eventTitle'] as String? ?? '',
      eventCoverImageUrl: map['eventCoverImageUrl'] as String?,
      eventVenue: map['eventVenue'] as String? ?? '',
      eventCity: map['eventCity'] as String? ?? '',
      buyerId: map['buyerId'] as String? ?? '',
      buyerName: map['buyerName'] as String? ?? '',
      items: rawItems
          .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      totalAmount: map['totalAmount'] as num? ?? 0,
      currency: map['currency'] as String? ?? 'XAF',
      paymentMethod: paymentMethodFromString(map['paymentMethod'] as String?),
      paymentPhone: map['paymentPhone'] as String? ?? '',
      promoCode: map['promoCode'] as String?,
      status: _orderStatusFromString(map['status'] as String?),
      createdAt: rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : null,
      confirmedAt:
          rawConfirmedAt is Timestamp ? rawConfirmedAt.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'eventTitle': eventTitle,
      'eventCoverImageUrl': eventCoverImageUrl,
      'eventVenue': eventVenue,
      'eventCity': eventCity,
      'buyerId': buyerId,
      'buyerName': buyerName,
      'items': items.map((i) => i.toMap()).toList(),
      'totalAmount': totalAmount,
      'currency': currency,
      'paymentMethod': paymentMethodToString(paymentMethod),
      'paymentPhone': paymentPhone,
      'promoCode': promoCode,
      'status': _orderStatusToString(status),
      'createdAt': FieldValue.serverTimestamp(),
      'confirmedAt': null,
    };
  }
}
