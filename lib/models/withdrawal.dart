import 'package:cloud_firestore/cloud_firestore.dart';

import 'payment_method.dart';

/// Cycle de vie d'une demande de retrait :
/// `pending` (envoyée à l'administrateur) → `approved` (validée, paiement
/// en cours) → `paid` (argent envoyé, référence Mobile Money saisie).
/// L'administrateur peut aussi la refuser (`rejected`, avec un motif) ;
/// l'organisateur peut l'annuler tant qu'elle est `pending`.
enum WithdrawalStatus { pending, approved, paid, rejected, cancelled }

WithdrawalStatus withdrawalStatusFromString(String? raw) {
  switch (raw) {
    case 'approved':
      return WithdrawalStatus.approved;
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

String withdrawalStatusToString(WithdrawalStatus status) {
  switch (status) {
    case WithdrawalStatus.approved:
      return 'approved';
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

String withdrawalStatusLabel(WithdrawalStatus status) {
  switch (status) {
    case WithdrawalStatus.pending:
      return 'En attente';
    case WithdrawalStatus.approved:
      return 'Validé · paiement en cours';
    case WithdrawalStatus.paid:
      return 'Payé';
    case WithdrawalStatus.rejected:
      return 'Refusé';
    case WithdrawalStatus.cancelled:
      return 'Annulé';
  }
}

/// Demande de retrait des gains d'une organisation certifiée, envoyée
/// vers un numéro Mobile Money. Stockée dans Firestore, collection
/// `withdrawals`. Chaque demande reçoit un numéro séquentiel ([number],
/// affiché `RET-000042`) pour être traitée dans l'ordre d'arrivée par
/// l'administrateur, qui envoie l'argent manuellement.
class Withdrawal {
  final String id;
  final int number;
  final String organisationId;
  final String organisationName;
  final String ownerId;

  final num amount;
  final PaymentMethod paymentMethod;
  final String phone;

  final WithdrawalStatus status;
  final String? rejectionReason;

  /// Référence de la transaction Mobile Money saisie à l'envoi.
  final String? transactionRef;

  final DateTime? createdAt;
  final DateTime? approvedAt;
  final DateTime? paidAt;
  final DateTime? rejectedAt;
  final DateTime? cancelledAt;

  const Withdrawal({
    required this.id,
    this.number = 0,
    required this.organisationId,
    required this.organisationName,
    required this.ownerId,
    required this.amount,
    required this.paymentMethod,
    required this.phone,
    this.status = WithdrawalStatus.pending,
    this.rejectionReason,
    this.transactionRef,
    this.createdAt,
    this.approvedAt,
    this.paidAt,
    this.rejectedAt,
    this.cancelledAt,
  });

  String get reference =>
      number > 0 ? 'RET-${number.toString().padLeft(6, '0')}' : 'RET-${id.substring(0, 6).toUpperCase()}';

  /// Montant encore bloqué sur le solde (ni payé, ni refusé/annulé).
  bool get isOpen => status == WithdrawalStatus.pending || status == WithdrawalStatus.approved;

  static DateTime? _date(dynamic raw) => raw is Timestamp ? raw.toDate() : null;

  factory Withdrawal.fromMap(String id, Map<String, dynamic> map) {
    return Withdrawal(
      id: id,
      number: (map['number'] as num?)?.toInt() ?? 0,
      organisationId: map['organisationId'] as String? ?? '',
      organisationName: map['organisationName'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      amount: map['amount'] as num? ?? 0,
      paymentMethod: paymentMethodFromString(map['paymentMethod'] as String?),
      phone: map['phone'] as String? ?? '',
      status: withdrawalStatusFromString(map['status'] as String?),
      rejectionReason: map['rejectionReason'] as String?,
      transactionRef: map['transactionRef'] as String?,
      createdAt: _date(map['createdAt']),
      approvedAt: _date(map['approvedAt']),
      paidAt: _date(map['paidAt']),
      rejectedAt: _date(map['rejectedAt']),
      cancelledAt: _date(map['cancelledAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'number': number,
      'organisationId': organisationId,
      'organisationName': organisationName,
      'ownerId': ownerId,
      'amount': amount,
      'paymentMethod': paymentMethodToString(paymentMethod),
      'phone': phone,
      'status': withdrawalStatusToString(status),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
