import 'package:cloud_firestore/cloud_firestore.dart';

import 'payment_method.dart';

enum WithdrawalStatus { pending, paid, rejected, cancelled }

WithdrawalStatus _withdrawalStatusFromString(String? raw) {
  switch (raw) {
    case 'paid':
      return WithdrawalStatus.paid;
    case 'rejected':
      return WithdrawalStatus.rejected;
    case 'cancelled':
      return WithdrawalStatus.cancelled;
    default:
      return WithdrawalStatus.pending;
  }
}

String _withdrawalStatusToString(WithdrawalStatus status) {
  switch (status) {
    case WithdrawalStatus.paid:
      return 'paid';
    case WithdrawalStatus.rejected:
      return 'rejected';
    case WithdrawalStatus.cancelled:
      return 'cancelled';
    case WithdrawalStatus.pending:
      return 'pending';
  }
}

/// Demande de retrait des gains d'une organisation, envoyée vers un
/// numéro Mobile Money. Stockée dans Firestore, collection `withdrawals`.
/// Aucune passerelle de paiement sortant réelle n'est branchée : la
/// demande reste "en attente" jusqu'à un traitement manuel côté équipe,
/// comme le paiement des commandes est lui-même simulé côté acheteur.
class Withdrawal {
  final String id;
  final String organisationId;
  final String organisationName;
  final String ownerId;

  final num amount;
  final PaymentMethod paymentMethod;
  final String phone;

  final WithdrawalStatus status;
  final DateTime? createdAt;
  final DateTime? processedAt;

  const Withdrawal({
    required this.id,
    required this.organisationId,
    required this.organisationName,
    required this.ownerId,
    required this.amount,
    required this.paymentMethod,
    required this.phone,
    this.status = WithdrawalStatus.pending,
    this.createdAt,
    this.processedAt,
  });

  factory Withdrawal.fromMap(String id, Map<String, dynamic> map) {
    final rawCreatedAt = map['createdAt'];
    final rawProcessedAt = map['processedAt'];
    return Withdrawal(
      id: id,
      organisationId: map['organisationId'] as String? ?? '',
      organisationName: map['organisationName'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      amount: map['amount'] as num? ?? 0,
      paymentMethod: paymentMethodFromString(map['paymentMethod'] as String?),
      phone: map['phone'] as String? ?? '',
      status: _withdrawalStatusFromString(map['status'] as String?),
      createdAt: rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : null,
      processedAt:
          rawProcessedAt is Timestamp ? rawProcessedAt.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organisationId': organisationId,
      'organisationName': organisationName,
      'ownerId': ownerId,
      'amount': amount,
      'paymentMethod': paymentMethodToString(paymentMethod),
      'phone': phone,
      'status': _withdrawalStatusToString(status),
      'createdAt': FieldValue.serverTimestamp(),
      'processedAt': null,
    };
  }
}
