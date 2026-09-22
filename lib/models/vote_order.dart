import 'package:cloud_firestore/cloud_firestore.dart';

import 'payment_method.dart';

enum VoteOrderStatus { pending, confirmed, cancelled }

VoteOrderStatus _statusFromString(String? raw) {
  switch (raw) {
    case 'confirmed':
      return VoteOrderStatus.confirmed;
    case 'cancelled':
      return VoteOrderStatus.cancelled;
    default:
      return VoteOrderStatus.pending;
  }
}

String _statusToString(VoteOrderStatus status) {
  switch (status) {
    case VoteOrderStatus.confirmed:
      return 'confirmed';
    case VoteOrderStatus.cancelled:
      return 'cancelled';
    case VoteOrderStatus.pending:
      return 'pending';
  }
}

/// Achat de votes pour un candidat, payé par Mobile Money. Stocké dans
/// Firestore, collection `voteOrders`. À la confirmation, le compteur de
/// votes du candidat est incrémenté de [quantity] (voir
/// `VoteService.confirmVoteOrder`).
class VoteOrder {
  final String id;
  final String campaignId;
  final String campaignTitle;
  final String organisationId;
  final String organisationName;
  final String ownerId;
  final String categoryId;
  final String categoryTitle;
  final String candidateId;
  final String candidateName;

  final int quantity;
  final num unitPrice;
  final num totalAmount;

  final String buyerId;
  final String buyerName;

  final PaymentMethod paymentMethod;
  final String paymentPhone;

  final VoteOrderStatus status;
  final DateTime? createdAt;
  final DateTime? confirmedAt;

  const VoteOrder({
    required this.id,
    required this.campaignId,
    required this.campaignTitle,
    required this.organisationId,
    required this.organisationName,
    required this.ownerId,
    required this.categoryId,
    required this.categoryTitle,
    required this.candidateId,
    required this.candidateName,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    required this.buyerId,
    required this.buyerName,
    required this.paymentMethod,
    required this.paymentPhone,
    this.status = VoteOrderStatus.pending,
    this.createdAt,
    this.confirmedAt,
  });

  factory VoteOrder.fromMap(String id, Map<String, dynamic> map) {
    final rawCreatedAt = map['createdAt'];
    final rawConfirmedAt = map['confirmedAt'];
    return VoteOrder(
      id: id,
      campaignId: map['campaignId'] as String? ?? '',
      campaignTitle: map['campaignTitle'] as String? ?? '',
      organisationId: map['organisationId'] as String? ?? '',
      organisationName: map['organisationName'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      categoryId: map['categoryId'] as String? ?? '',
      categoryTitle: map['categoryTitle'] as String? ?? '',
      candidateId: map['candidateId'] as String? ?? '',
      candidateName: map['candidateName'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: map['unitPrice'] as num? ?? 0,
      totalAmount: map['totalAmount'] as num? ?? 0,
      buyerId: map['buyerId'] as String? ?? '',
      buyerName: map['buyerName'] as String? ?? '',
      paymentMethod: paymentMethodFromString(map['paymentMethod'] as String?),
      paymentPhone: map['paymentPhone'] as String? ?? '',
      status: _statusFromString(map['status'] as String?),
      createdAt: rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : null,
      confirmedAt:
          rawConfirmedAt is Timestamp ? rawConfirmedAt.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'campaignId': campaignId,
      'campaignTitle': campaignTitle,
      'organisationId': organisationId,
      'organisationName': organisationName,
      'ownerId': ownerId,
      'categoryId': categoryId,
      'categoryTitle': categoryTitle,
      'candidateId': candidateId,
      'candidateName': candidateName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalAmount': totalAmount,
      'buyerId': buyerId,
      'buyerName': buyerName,
      'paymentMethod': paymentMethodToString(paymentMethod),
      'paymentPhone': paymentPhone,
      'status': _statusToString(status),
      'createdAt': FieldValue.serverTimestamp(),
      'confirmedAt': null,
    };
  }
}
