import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/order.dart';
import '../models/payment_method.dart';
import '../models/vote_order.dart';
import '../models/withdrawal.dart';
import 'auth_service.dart';

/// Même taux que la vue financière par événement
/// (voir `_platformCommissionRate` dans event_management_screen.dart).
const kPlatformCommissionRate = 0.10;

/// Une entrée de recette (vente de billets ou achat de votes confirmé)
/// qui compte dans le solde de l'organisation. Sert à l'historique
/// complet des transactions du portefeuille.
class WalletTransaction {
  final String id;
  final String label;
  final String type;
  final num grossAmount;
  final DateTime? date;

  const WalletTransaction({
    required this.id,
    required this.label,
    required this.type,
    required this.grossAmount,
    this.date,
  });

  /// Part qui revient à l'organisateur une fois la commission retirée.
  num get netAmount => grossAmount * (1 - kPlatformCommissionRate);
}

/// Résumé financier d'une organisation, tous événements confondus.
class WalletSummary {
  final num grossRevenue;
  final num commission;
  final num netRevenue;
  final num withdrawn;
  final num pendingWithdrawals;
  final num availableBalance;

  const WalletSummary({
    required this.grossRevenue,
    required this.commission,
    required this.netRevenue,
    required this.withdrawn,
    required this.pendingWithdrawals,
    required this.availableBalance,
  });

  static const empty = WalletSummary(
    grossRevenue: 0,
    commission: 0,
    netRevenue: 0,
    withdrawn: 0,
    pendingWithdrawals: 0,
    availableBalance: 0,
  );
}

/// Gains d'une organisation (commandes confirmées de tous ses
/// événements) et demandes de retrait. Aucune passerelle de paiement
/// sortant réelle n'est branchée : une demande reste "en attente" jusqu'à
/// un traitement manuel côté équipe.
class WalletService {
  WalletService._();
  static final WalletService instance = WalletService._();

  static const _timeout = Duration(seconds: 15);

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _withdrawals =>
      _db.collection('withdrawals');

  String? get _uid => AuthService.instance.currentUser?.uid;

  /// Exécute une requête et renvoie ses documents, ou une liste vide si
  /// elle échoue (permission refusée sur un vieux document sans
  /// `ownerId`, index en cours de construction, réseau...). Le
  /// portefeuille reste ainsi une estimation qui s'affiche toujours,
  /// plutôt qu'un tout-ou-rien qui casse sur la moindre donnée isolée.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _safeDocs(
      Query<Map<String, dynamic>> query) async {
    try {
      final snap = await query.get().timeout(_timeout);
      return snap.docs;
    } catch (_) {
      return const [];
    }
  }

  /// Additionne les commandes confirmées de tous les événements de
  /// l'organisation, puis retire ce qui a déjà été retiré ou est en
  /// attente de retrait, pour obtenir le solde disponible.
  Future<WalletSummary> fetchSummary(String organisationId) async {
    final eventDocs = await _safeDocs(
        _db.collection('events').where('organisationId', isEqualTo: organisationId));

    num gross = 0;
    final ordersDocsList = await Future.wait(eventDocs.map(
      (eventDoc) => _safeDocs(_db.collection('orders').where('eventId', isEqualTo: eventDoc.id)),
    ));
    for (final orderDocs in ordersDocsList) {
      for (final orderDoc in orderDocs) {
        final order = TicketOrder.fromMap(orderDoc.id, orderDoc.data());
        if (order.status == OrderStatus.confirmed) {
          gross += order.totalAmount;
        }
      }
    }

    // Recettes des campagnes de vote de l'organisation (achats de votes
    // confirmés), qui comptent pour le même solde.
    final voteOrderDocs = await _safeDocs(
        _db.collection('voteOrders').where('organisationId', isEqualTo: organisationId));
    for (final doc in voteOrderDocs) {
      final order = VoteOrder.fromMap(doc.id, doc.data());
      if (order.status == VoteOrderStatus.confirmed) {
        gross += order.totalAmount;
      }
    }

    final withdrawalDocs =
        await _safeDocs(_withdrawals.where('organisationId', isEqualTo: organisationId));
    num withdrawn = 0;
    num pending = 0;
    for (final doc in withdrawalDocs) {
      final w = Withdrawal.fromMap(doc.id, doc.data());
      if (w.status == WithdrawalStatus.paid) {
        withdrawn += w.amount;
      } else if (w.status == WithdrawalStatus.pending) {
        pending += w.amount;
      }
    }

    final commission = gross * kPlatformCommissionRate;
    final net = gross - commission;
    final available = net - withdrawn - pending;

    return WalletSummary(
      grossRevenue: gross,
      commission: commission,
      netRevenue: net,
      withdrawn: withdrawn,
      pendingWithdrawals: pending,
      availableBalance: available < 0 ? 0 : available,
    );
  }

  /// Toutes les transactions confirmées (ventes de billets + achats de
  /// votes) qui ont compté dans le solde de l'organisation, les plus
  /// récentes d'abord. Donne à l'organisateur une vue complète de
  /// l'argent qui a transité, pas seulement le total agrégé.
  Future<List<WalletTransaction>> fetchTransactions(String organisationId) async {
    final transactions = <WalletTransaction>[];

    final eventDocs = await _safeDocs(
        _db.collection('events').where('organisationId', isEqualTo: organisationId));
    final ordersDocsList = await Future.wait(eventDocs.map(
      (eventDoc) => _safeDocs(_db.collection('orders').where('eventId', isEqualTo: eventDoc.id)),
    ));
    for (var i = 0; i < eventDocs.length; i++) {
      final eventTitle = eventDocs[i].data()['title'] as String? ?? '';
      for (final orderDoc in ordersDocsList[i]) {
        final order = TicketOrder.fromMap(orderDoc.id, orderDoc.data());
        if (order.status != OrderStatus.confirmed) continue;
        transactions.add(WalletTransaction(
          id: order.id,
          label: eventTitle.isEmpty ? order.eventTitle : eventTitle,
          type: 'Billetterie',
          grossAmount: order.totalAmount,
          date: order.confirmedAt ?? order.createdAt,
        ));
      }
    }

    final voteOrderDocs = await _safeDocs(
        _db.collection('voteOrders').where('organisationId', isEqualTo: organisationId));
    for (final doc in voteOrderDocs) {
      final order = VoteOrder.fromMap(doc.id, doc.data());
      if (order.status != VoteOrderStatus.confirmed) continue;
      transactions.add(WalletTransaction(
        id: order.id,
        label: order.campaignTitle,
        type: 'Vote',
        grossAmount: order.totalAmount,
        date: order.confirmedAt ?? order.createdAt,
      ));
    }

    transactions.sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
    return transactions;
  }

  Stream<List<Withdrawal>> watchWithdrawals(String organisationId) {
    return _withdrawals
        .where('organisationId', isEqualTo: organisationId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Withdrawal.fromMap(d.id, d.data())).toList())
        .handleError((_) => <Withdrawal>[]);
  }

  Future<void> requestWithdrawal({
    required String organisationId,
    required String organisationName,
    required num amount,
    required PaymentMethod paymentMethod,
    required String phone,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Utilisateur non connecté.');
    if (amount <= 0) throw StateError('Le montant doit être supérieur à 0.');
    if (phone.trim().isEmpty) {
      throw StateError('Le numéro Mobile Money est requis.');
    }

    final summary = await fetchSummary(organisationId);
    if (amount > summary.availableBalance) {
      throw StateError('Solde insuffisant pour ce retrait.');
    }

    final doc = _withdrawals.doc();
    final withdrawal = Withdrawal(
      id: doc.id,
      organisationId: organisationId,
      organisationName: organisationName,
      ownerId: uid,
      amount: amount,
      paymentMethod: paymentMethod,
      phone: phone.trim(),
    );
    await doc.set(withdrawal.toMap()).timeout(_timeout);
  }

  /// Annule une demande encore en attente (aucun traitement en cours).
  Future<void> cancelWithdrawal(String withdrawalId) {
    return _withdrawals.doc(withdrawalId).delete().timeout(_timeout);
  }
}
