import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/order.dart';
import '../models/organisation.dart';
import '../models/payment_method.dart';
import '../models/vote_order.dart';
import '../models/withdrawal.dart';
import 'auth_service.dart';

/// Même taux que la vue financière par événement
/// (voir `_platformCommissionRate` dans event_management_screen.dart).
const kPlatformCommissionRate = 0.10;

/// Montant minimum d'une demande de retrait.
const kMinWithdrawalAmount = 1000;

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

  // Toutes les requêtes sur `orders`, `tickets`, `voteOrders` et
  // `withdrawals` doivent filtrer sur `buyerId` ou `ownerId` : les règles
  // Firestore refusent sinon la requête en ligne (le cache hors ligne,
  // lui, ne vérifie pas les règles, d'où des données qui n'apparaissent
  // que sans connexion).

  /// Exécute une requête et renvoie ses documents. Une erreur remonte à
  /// l'écran (message + "Réessayer") au lieu d'être masquée : mieux vaut
  /// signaler un échec que d'afficher un faux solde de 0 FCFA.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _safeDocs(
      Query<Map<String, dynamic>> query) async {
    final snap = await query.get().timeout(_timeout);
    return snap.docs;
  }

  /// Additionne les commandes confirmées de tous les événements de
  /// l'organisation, puis retire ce qui a déjà été retiré ou est en
  /// attente de retrait, pour obtenir le solde disponible.
  ///
  /// [ownerId] (propriétaire de l'organisation) vaut par défaut
  /// l'utilisateur courant ; l'administrateur le passe pour contrôler le
  /// solde d'une organisation avant de valider un retrait.
  Future<WalletSummary> fetchSummary(String organisationId, {String? ownerId}) async {
    final owner = ownerId ?? _uid;
    final eventDocs = await _safeDocs(
        _db.collection('events').where('organisationId', isEqualTo: organisationId));

    num gross = 0;
    final ordersDocsList = await Future.wait(eventDocs.map(
      (eventDoc) => _safeDocs(_db
          .collection('orders')
          .where('ownerId', isEqualTo: owner)
          .where('eventId', isEqualTo: eventDoc.id)),
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
        _db
            .collection('voteOrders')
            .where('ownerId', isEqualTo: owner)
            .where('organisationId', isEqualTo: organisationId));
    for (final doc in voteOrderDocs) {
      final order = VoteOrder.fromMap(doc.id, doc.data());
      if (order.status == VoteOrderStatus.confirmed) {
        gross += order.totalAmount;
      }
    }

    final withdrawalDocs =
        await _safeDocs(_withdrawals
            .where('ownerId', isEqualTo: owner)
            .where('organisationId', isEqualTo: organisationId));
    num withdrawn = 0;
    num pending = 0;
    for (final doc in withdrawalDocs) {
      final w = Withdrawal.fromMap(doc.id, doc.data());
      if (w.status == WithdrawalStatus.paid) {
        withdrawn += w.amount;
      } else if (w.isOpen) {
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
      (eventDoc) => _safeDocs(_db
          .collection('orders')
          .where('ownerId', isEqualTo: _uid)
          .where('eventId', isEqualTo: eventDoc.id)),
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
        _db
            .collection('voteOrders')
            .where('ownerId', isEqualTo: _uid)
            .where('organisationId', isEqualTo: organisationId));
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
    // Tri côté app : évite un index composite supplémentaire.
    return _withdrawals
        .where('ownerId', isEqualTo: _uid)
        .where('organisationId', isEqualTo: organisationId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Withdrawal.fromMap(d.id, d.data()))
            .toList()
          ..sort((a, b) => (b.createdAt ?? DateTime(0))
              .compareTo(a.createdAt ?? DateTime(0))))
        .handleError((_) => <Withdrawal>[]);
  }

  /// Envoie une demande de retrait à l'administrateur. Conditions :
  /// organisation certifiée et non bloquée, aucune autre demande en cours
  /// (une seule à la fois, traitée dans l'ordre), solde suffisant.
  /// Chaque demande reçoit un numéro séquentiel global (`counters/
  /// withdrawals`) attribué dans une transaction.
  Future<void> requestWithdrawal({
    required Organisation organisation,
    required num amount,
    required PaymentMethod paymentMethod,
    required String phone,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Utilisateur non connecté.');
    if (organisation.blocked) {
      throw StateError("Cette organisation est bloquée par l'administrateur.");
    }
    if (!organisation.certified) {
      throw StateError("L'organisation doit être certifiée par l'administrateur avant de retirer.");
    }
    if (amount < kMinWithdrawalAmount) {
      throw StateError('Le retrait minimum est de $kMinWithdrawalAmount XAF.');
    }
    if (phone.trim().length < 8) {
      throw StateError('Le numéro Mobile Money est invalide.');
    }

    final existing = await _safeDocs(_withdrawals
        .where('ownerId', isEqualTo: uid)
        .where('organisationId', isEqualTo: organisation.id));
    final hasOpen = existing.any((d) => Withdrawal.fromMap(d.id, d.data()).isOpen);
    if (hasOpen) {
      throw StateError(
          "Une demande est déjà en cours de traitement. Attendez sa validation avant d'en faire une autre.");
    }

    final summary = await fetchSummary(organisation.id);
    if (amount > summary.availableBalance) {
      throw StateError('Solde insuffisant pour ce retrait.');
    }

    final counterRef = _db.collection('counters').doc('withdrawals');
    final doc = _withdrawals.doc();
    await _db.runTransaction((tx) async {
      final counter = await tx.get(counterRef);
      final number = counter.exists ? ((counter.data()!['next'] as num?)?.toInt() ?? 1) : 1;
      final withdrawal = Withdrawal(
        id: doc.id,
        number: number,
        organisationId: organisation.id,
        organisationName: organisation.name,
        ownerId: uid,
        amount: amount,
        paymentMethod: paymentMethod,
        phone: phone.trim(),
      );
      tx.set(doc, withdrawal.toMap());
      if (counter.exists) {
        tx.update(counterRef, {'next': number + 1});
      } else {
        tx.set(counterRef, {'next': number + 1});
      }
    }).timeout(_timeout);
  }

  /// Annule une demande encore en attente. Elle reste dans l'historique
  /// (statut "Annulé") pour garder une trace complète et ordonnée.
  Future<void> cancelWithdrawal(String withdrawalId) {
    return _withdrawals.doc(withdrawalId).update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    }).timeout(_timeout);
  }
}
