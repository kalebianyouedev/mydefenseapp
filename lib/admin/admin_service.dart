import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/event.dart';
import '../models/order.dart';
import '../models/organisation.dart';
import '../models/vote_campaign.dart';
import '../models/vote_order.dart';
import '../models/withdrawal.dart';
import '../services/account_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/wallet_service.dart';

/// Compte utilisateur vu par l'administrateur : fiche `users/{uid}` +
/// statut de modération `userModeration/{uid}`.
class AdminUser {
  final String uid;
  final String email;
  final String name;
  final String phone;
  final String city;
  final String? photoUrl;
  final DateTime? lastSeenAt;
  final DateTime? createdAt;
  final AccountModeration moderation;
  final bool isAdmin;

  const AdminUser({
    required this.uid,
    this.email = '',
    this.name = '',
    this.phone = '',
    this.city = '',
    this.photoUrl,
    this.lastSeenAt,
    this.createdAt,
    this.moderation = AccountModeration.none,
    this.isAdmin = false,
  });

  String get displayName => name.isNotEmpty ? name : (email.isNotEmpty ? email : uid);

  static DateTime? _date(dynamic raw) => raw is Timestamp ? raw.toDate() : null;

  factory AdminUser.fromMap(String uid, Map<String, dynamic> map,
      {AccountModeration moderation = AccountModeration.none, bool isAdmin = false}) {
    final name = [map['firstName'], map['lastName']]
        .whereType<String>()
        .where((e) => e.trim().isNotEmpty)
        .join(' ');
    return AdminUser(
      uid: uid,
      email: map['email'] as String? ?? '',
      name: name.isNotEmpty ? name : (map['displayName'] as String? ?? ''),
      phone: map['phone'] as String? ?? '',
      city: map['city'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      lastSeenAt: _date(map['lastSeenAt']),
      createdAt: _date(map['accountCreatedAt']),
      moderation: moderation,
      isAdmin: isAdmin,
    );
  }
}

class AdminLogEntry {
  final String id;
  final String action;
  final String target;
  final String adminEmail;
  final String? details;
  final DateTime? at;

  const AdminLogEntry({
    required this.id,
    required this.action,
    required this.target,
    required this.adminEmail,
    this.details,
    this.at,
  });

  factory AdminLogEntry.fromMap(String id, Map<String, dynamic> map) {
    final at = map['at'];
    return AdminLogEntry(
      id: id,
      action: map['action'] as String? ?? '',
      target: map['target'] as String? ?? '',
      adminEmail: map['adminEmail'] as String? ?? '',
      details: map['details'] as String?,
      at: at is Timestamp ? at.toDate() : null,
    );
  }
}

class AdminStats {
  final int users;
  final int blockedUsers;
  final int organisations;
  final int certifiedOrganisations;
  final int certificationRequests;
  final int publishedEvents;
  final int activeCampaigns;
  final int pendingWithdrawals;
  final num pendingWithdrawalAmount;
  final num paidWithdrawalAmount;
  final num ticketRevenue;
  final num voteRevenue;
  final num boostRevenue;

  const AdminStats({
    required this.users,
    required this.blockedUsers,
    required this.organisations,
    required this.certifiedOrganisations,
    required this.certificationRequests,
    required this.publishedEvents,
    required this.activeCampaigns,
    required this.pendingWithdrawals,
    required this.pendingWithdrawalAmount,
    required this.paidWithdrawalAmount,
    required this.ticketRevenue,
    required this.voteRevenue,
    required this.boostRevenue,
  });

  num get grossRevenue => ticketRevenue + voteRevenue;

  /// Revenus de la plateforme : commission sur billets et votes + boosts.
  num get platformRevenue => grossRevenue * kPlatformCommissionRate + boostRevenue;
}

enum AdminPaymentKind { tickets, votes, boost }

/// Un paiement reçu sur la plateforme (billets, votes ou boost).
class AdminPayment {
  final String id;
  final AdminPaymentKind kind;
  final String title;
  final String organisationName;
  final String buyerName;
  final num amount;
  final String status; // confirmed | pending | cancelled
  final String method;
  final DateTime? date;

  const AdminPayment({
    required this.id,
    required this.kind,
    required this.title,
    required this.organisationName,
    required this.buyerName,
    required this.amount,
    required this.status,
    required this.method,
    this.date,
  });

  String get reference => 'PAY-${id.substring(0, id.length < 8 ? id.length : 8).toUpperCase()}';

  bool get confirmed => status == 'confirmed';

  String get kindLabel => switch (kind) {
        AdminPaymentKind.tickets => 'Billets',
        AdminPaymentKind.votes => 'Votes',
        AdminPaymentKind.boost => 'Boost',
      };
}

/// Données du tableau de bord, mises à jour en temps réel.
class AdminDashboardData {
  final List<AdminPayment> payments;
  final List<Event> events;
  final List<VoteCampaign> campaigns;
  final List<Organisation> organisations;
  final List<Withdrawal> withdrawals;
  final int userCount;

  const AdminDashboardData({
    required this.payments,
    required this.events,
    required this.campaigns,
    required this.organisations,
    required this.withdrawals,
    required this.userCount,
  });

  Iterable<AdminPayment> get confirmedPayments => payments.where((p) => p.confirmed);

  num get salesVolume => confirmedPayments
      .where((p) => p.kind != AdminPaymentKind.boost)
      .fold<num>(0, (s, p) => s + p.amount);

  num get boostRevenue =>
      confirmedPayments.where((p) => p.kind == AdminPaymentKind.boost).fold<num>(0, (s, p) => s + p.amount);

  /// Revenus nets de la plateforme : commission sur billets et votes +
  /// boosts.
  num get platformRevenue => salesVolume * kPlatformCommissionRate + boostRevenue;

  /// Montants encaissés par mois sur les [months] derniers mois (le plus
  /// ancien d'abord).
  List<(DateTime, num)> monthlyVolume({int months = 6}) {
    final now = DateTime.now();
    final buckets = <(DateTime, num)>[
      for (var i = months - 1; i >= 0; i--) (DateTime(now.year, now.month - i), 0),
    ];
    final totals = List<num>.filled(months, 0);
    for (final p in confirmedPayments) {
      final d = p.date;
      if (d == null) continue;
      for (var i = 0; i < months; i++) {
        final m = buckets[i].$1;
        if (d.year == m.year && d.month == m.month) totals[i] += p.amount;
      }
    }
    return [for (var i = 0; i < months; i++) (buckets[i].$1, totals[i])];
  }
}

/// Toutes les opérations de l'espace administrateur. Les droits sont
/// garantis par firestore.rules (fonction `isAdmin()`), pas par l'app :
/// un compte non administrateur ne peut rien lire ni modifier ici.
class AdminService {
  AdminService._();
  static final AdminService instance = AdminService._();

  static const _timeout = Duration(seconds: 20);

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _moderation => _db.collection('userModeration');
  CollectionReference<Map<String, dynamic>> get _admins => _db.collection('admins');
  CollectionReference<Map<String, dynamic>> get _organisations => _db.collection('organisations');
  CollectionReference<Map<String, dynamic>> get _events => _db.collection('events');
  CollectionReference<Map<String, dynamic>> get _campaigns => _db.collection('voteCampaigns');
  CollectionReference<Map<String, dynamic>> get _withdrawals => _db.collection('withdrawals');
  CollectionReference<Map<String, dynamic>> get _logs => _db.collection('adminLogs');

  // ---------------------------------------------------------------------
  // Session admin
  // ---------------------------------------------------------------------

  /// Connexion à l'espace admin : email + mot de passe, puis vérification
  /// du rôle. Un compte sans rôle admin est aussitôt déconnecté.
  Future<void> signIn(String email, String password) async {
    await AuthService.instance.signInWithEmail(email: email, password: password);
    final uid = AuthService.instance.currentUser?.uid;
    final ok = uid != null && await AccountService.instance.isAdmin(uid);
    if (!ok) {
      await AuthService.instance.signOut();
      throw StateError("Ce compte n'a pas les droits administrateur.");
    }
    await _log('Connexion', 'Espace administrateur');
  }

  Future<bool> currentUserIsAdmin() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return false;
    try {
      return await AccountService.instance.isAdmin(uid);
    } catch (_) {
      return false;
    }
  }

  Future<void> _log(String action, String target, {String? details}) async {
    final user = AuthService.instance.currentUser;
    try {
      await _logs.add({
        'action': action,
        'target': target,
        'details': details,
        'adminUid': user?.uid,
        'adminEmail': user?.email ?? '',
        'at': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Le journal ne doit jamais faire échouer l'action elle-même.
    }
  }

  /// Prévient l'utilisateur concerné, en temps réel, dans l'app mobile.
  /// Un échec d'envoi ne doit jamais annuler l'action admin.
  Future<void> _notify(String uid, AppNotificationType type, String title, String body, {bool? positive}) async {
    if (uid.isEmpty) return;
    try {
      await NotificationService.instance.send(uid: uid, type: type, title: title, body: body, positive: positive);
    } catch (_) {}
  }

  Stream<List<AdminLogEntry>> watchLogs() {
    return _logs
        .orderBy('at', descending: true)
        .limit(300)
        .snapshots()
        .map((s) => s.docs.map((d) => AdminLogEntry.fromMap(d.id, d.data())).toList());
  }

  // ---------------------------------------------------------------------
  // Utilisateurs
  // ---------------------------------------------------------------------

  Stream<List<Map<String, dynamic>>> _rawUsers() =>
      _users.snapshots().map((s) => s.docs.map((d) => {'_id': d.id, ...d.data()}).toList());

  Stream<Map<String, AccountModeration>> watchModeration() => _moderation.snapshots().map(
      (s) => {for (final d in s.docs) d.id: AccountModeration.fromMap(d.data())});

  Stream<Set<String>> watchAdminIds() =>
      _admins.snapshots().map((s) => s.docs.map((d) => d.id).toSet());

  /// Utilisateurs, avec leur statut et rôle, les plus récemment vus
  /// d'abord.
  Stream<List<AdminUser>> watchUsers() {
    return _combine3(_rawUsers(), watchModeration(), watchAdminIds(), (users, moderation, admins) {
      final list = users.map((m) {
        final id = m['_id'] as String;
        return AdminUser.fromMap(id, m,
            moderation: moderation[id] ?? AccountModeration.none, isAdmin: admins.contains(id));
      }).toList()
        ..sort((a, b) => (b.lastSeenAt ?? b.createdAt ?? DateTime(0))
            .compareTo(a.lastSeenAt ?? a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  Future<void> setUserBlocked(AdminUser user, bool blocked, {String? reason}) async {
    await _moderation.doc(user.uid).set({
      'blocked': blocked,
      'reason': blocked ? (reason?.trim().isEmpty ?? true ? null : reason!.trim()) : null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).timeout(_timeout);
    await _log(blocked ? 'Utilisateur bloqué' : 'Utilisateur débloqué', user.displayName, details: reason);
  }

  /// Supprime le compte côté application : fiche utilisateur effacée,
  /// compte marqué supprimé/bloqué (il ne peut plus se connecter) et ses
  /// organisations supprimées avec leurs événements et votes. Le compte
  /// d'authentification Firebase lui-même ne peut être effacé que depuis
  /// la console Firebase (ou une Cloud Function).
  Future<void> deleteUser(AdminUser user) async {
    final orgs = await _organisations.where('ownerId', isEqualTo: user.uid).get().timeout(_timeout);
    for (final o in orgs.docs) {
      await _deleteOrganisationCascade(o.id);
    }
    await _moderation.doc(user.uid).set({
      'blocked': true,
      'deleted': true,
      'reason': 'Compte supprimé',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).timeout(_timeout);
    await _users.doc(user.uid).delete().timeout(_timeout);
    await _log('Utilisateur supprimé', user.displayName,
        details: '${orgs.docs.length} organisation(s) supprimée(s)');
  }

  Future<void> setAdmin(AdminUser user, bool admin) async {
    if (admin) {
      await _admins.doc(user.uid).set({
        'email': user.email,
        'grantedBy': AuthService.instance.currentUser?.email,
        'grantedAt': FieldValue.serverTimestamp(),
      }).timeout(_timeout);
    } else {
      if (user.uid == AuthService.instance.currentUser?.uid) {
        throw StateError('Vous ne pouvez pas retirer vos propres droits.');
      }
      await _admins.doc(user.uid).delete().timeout(_timeout);
    }
    await _log(admin ? 'Droits admin accordés' : 'Droits admin retirés', user.displayName);
  }

  // ---------------------------------------------------------------------
  // Organisations
  // ---------------------------------------------------------------------

  Stream<List<Organisation>> watchOrganisations() {
    return _organisations.snapshots().map((s) {
      final list = s.docs.map((d) => Organisation.fromMap(d.id, d.data())).toList();
      // Demandes de certification d'abord (les plus anciennes en tête),
      // puis les autres par date de création.
      list.sort((a, b) {
        final ra = a.certificationRequested && !a.certified;
        final rb = b.certificationRequested && !b.certified;
        if (ra != rb) return ra ? -1 : 1;
        if (ra && rb) {
          return (a.certificationRequestedAt ?? DateTime(0)).compareTo(b.certificationRequestedAt ?? DateTime(0));
        }
        return (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0));
      });
      return list;
    });
  }

  /// Applique [data] à tous les événements et campagnes de vote de
  /// l'organisation (badge certifié, masquage), par lots de 400.
  Future<void> _cascadeToContent(String organisationId, Map<String, dynamic> data) async {
    final events = await _events.where('organisationId', isEqualTo: organisationId).get().timeout(_timeout);
    final campaigns = await _campaigns.where('organisationId', isEqualTo: organisationId).get().timeout(_timeout);
    final refs = [...events.docs.map((d) => d.reference), ...campaigns.docs.map((d) => d.reference)];
    for (var i = 0; i < refs.length; i += 400) {
      final batch = _db.batch();
      for (final ref in refs.skip(i).take(400)) {
        batch.update(ref, data);
      }
      await batch.commit().timeout(_timeout);
    }
  }

  Future<void> setCertified(Organisation organisation, bool certified) async {
    await _organisations.doc(organisation.id).update({
      'certified': certified,
      'certifiedAt': certified ? FieldValue.serverTimestamp() : null,
      'certificationRequested': false,
    }).timeout(_timeout);
    await _cascadeToContent(organisation.id, {'organisationCertified': certified});
    await _log(certified ? 'Organisation certifiée' : 'Certification retirée', organisation.name);
    await _notify(
      organisation.ownerId,
      AppNotificationType.certification,
      certified ? '${organisation.name} est certifiée ✅' : 'Certification retirée',
      certified
          ? 'Votre organisation a le badge vérifié et peut maintenant demander des retraits depuis son portefeuille.'
          : "La certification de ${organisation.name} a été retirée. Les retraits sont suspendus.",
      positive: certified,
    );
  }

  /// Refuse une demande de certification (l'organisateur pourra la
  /// renouveler).
  Future<void> rejectCertification(Organisation organisation) async {
    await _organisations.doc(organisation.id).update({'certificationRequested': false}).timeout(_timeout);
    await _log('Certification refusée', organisation.name);
    await _notify(organisation.ownerId, AppNotificationType.certification, 'Certification refusée',
        "La demande de certification de ${organisation.name} n'a pas été acceptée. Vous pouvez compléter votre profil puis refaire une demande.",
        positive: false);
  }

  Future<void> setOrganisationBlocked(Organisation organisation, bool blocked, {String? reason}) async {
    await _organisations.doc(organisation.id).update({
      'blocked': blocked,
      'blockedReason': blocked ? (reason?.trim().isEmpty ?? true ? null : reason!.trim()) : null,
      'blockedAt': blocked ? FieldValue.serverTimestamp() : null,
    }).timeout(_timeout);
    await _cascadeToContent(organisation.id, {'hiddenByAdmin': blocked});
    await _log(blocked ? 'Organisation bloquée' : 'Organisation débloquée', organisation.name, details: reason);
    await _notify(
      organisation.ownerId,
      AppNotificationType.moderation,
      blocked ? '${organisation.name} est bloquée' : '${organisation.name} est débloquée',
      blocked
          ? 'Ses événements et votes sont masqués et les retraits suspendus.'
              '${reason?.trim().isNotEmpty == true ? ' Motif : ${reason!.trim()}' : ''}'
          : 'Vos événements et votes sont de nouveau visibles.',
      positive: !blocked,
    );
  }

  Future<void> _deleteOrganisationCascade(String organisationId) async {
    final events = await _events.where('organisationId', isEqualTo: organisationId).get().timeout(_timeout);
    final campaigns = await _campaigns.where('organisationId', isEqualTo: organisationId).get().timeout(_timeout);
    final refs = [
      ...events.docs.map((d) => d.reference),
      ...campaigns.docs.map((d) => d.reference),
      _organisations.doc(organisationId),
    ];
    for (var i = 0; i < refs.length; i += 400) {
      final batch = _db.batch();
      for (final ref in refs.skip(i).take(400)) {
        batch.delete(ref);
      }
      await batch.commit().timeout(_timeout);
    }
  }

  Future<void> deleteOrganisation(Organisation organisation) async {
    await _deleteOrganisationCascade(organisation.id);
    await _log('Organisation supprimée', organisation.name, details: 'avec ses événements et votes');
  }

  // ---------------------------------------------------------------------
  // Événements et votes
  // ---------------------------------------------------------------------

  Stream<List<Event>> watchEvents() {
    return _events.orderBy('createdAt', descending: true).snapshots().map(
        (s) => s.docs.map((d) => Event.fromMap(d.id, d.data())).toList());
  }

  Future<void> setEventHidden(Event event, bool hidden) async {
    await _events.doc(event.id).update({'hiddenByAdmin': hidden}).timeout(_timeout);
    await _log(hidden ? 'Événement masqué' : 'Événement rétabli', event.title);
  }

  Future<void> deleteEvent(Event event) async {
    await _events.doc(event.id).delete().timeout(_timeout);
    await _log('Événement supprimé', event.title, details: event.organisationName);
  }

  Stream<List<VoteCampaign>> watchCampaigns() {
    return _campaigns.orderBy('createdAt', descending: true).snapshots().map(
        (s) => s.docs.map((d) => VoteCampaign.fromMap(d.id, d.data())).toList());
  }

  Future<void> setCampaignHidden(VoteCampaign campaign, bool hidden) async {
    await _campaigns.doc(campaign.id).update({'hiddenByAdmin': hidden}).timeout(_timeout);
    await _log(hidden ? 'Vote masqué' : 'Vote rétabli', campaign.title);
  }

  Future<void> deleteCampaign(VoteCampaign campaign) async {
    await _campaigns.doc(campaign.id).delete().timeout(_timeout);
    await _log('Vote supprimé', campaign.title, details: campaign.organisationName);
  }

  // ---------------------------------------------------------------------
  // Retraits
  // ---------------------------------------------------------------------

  /// Toutes les demandes, de la plus ancienne à la plus récente (ordre de
  /// traitement).
  Stream<List<Withdrawal>> watchWithdrawals() {
    return _withdrawals.snapshots().map((s) {
      final list = s.docs.map((d) => Withdrawal.fromMap(d.id, d.data())).toList();
      list.sort((a, b) {
        final byNumber = a.number.compareTo(b.number);
        if (a.number > 0 && b.number > 0 && byNumber != 0) return byNumber;
        return (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0));
      });
      return list;
    });
  }

  Future<WalletSummary> fetchBalance(Withdrawal w) =>
      WalletService.instance.fetchSummary(w.organisationId, ownerId: w.ownerId);

  /// Fait avancer une demande en vérifiant son statut actuel dans une
  /// transaction (deux admins ne peuvent pas la traiter en même temps).
  Future<void> _transition(Withdrawal w, WithdrawalStatus from, Map<String, dynamic> data) async {
    final ref = _withdrawals.doc(w.id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('Demande introuvable.');
      final current = Withdrawal.fromMap(snap.id, snap.data()!);
      if (current.status != from) {
        throw StateError('Cette demande a déjà été traitée (${withdrawalStatusLabel(current.status)}).');
      }
      tx.update(ref, {
        ...data,
        'processedBy': AuthService.instance.currentUser?.email,
        'processedAt': FieldValue.serverTimestamp(),
      });
    }).timeout(_timeout);
  }

  Future<void> approveWithdrawal(Withdrawal w) async {
    await _transition(w, WithdrawalStatus.pending, {
      'status': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
    });
    await _log('Retrait validé', '${w.reference} · ${w.organisationName}', details: '${w.amount} XAF');
    await _notify(w.ownerId, AppNotificationType.withdrawal, 'Retrait ${w.reference} validé',
        'Votre demande de ${w.amount} XAF est validée. Le paiement vers le ${w.phone} est en cours.',
        positive: true);
  }

  Future<void> markWithdrawalPaid(Withdrawal w, String transactionRef) async {
    if (transactionRef.trim().isEmpty) {
      throw StateError('Saisissez la référence de la transaction Mobile Money.');
    }
    await _transition(w, WithdrawalStatus.approved, {
      'status': 'paid',
      'paidAt': FieldValue.serverTimestamp(),
      'transactionRef': transactionRef.trim(),
    });
    await _log('Retrait payé', '${w.reference} · ${w.organisationName}',
        details: '${w.amount} XAF · réf. ${transactionRef.trim()}');
    await _notify(w.ownerId, AppNotificationType.withdrawal, 'Retrait ${w.reference} payé 💸',
        '${w.amount} XAF ont été envoyés au ${w.phone}. Référence : ${transactionRef.trim()}.',
        positive: true);
  }

  Future<void> rejectWithdrawal(Withdrawal w, String reason) async {
    if (reason.trim().isEmpty) throw StateError('Indiquez le motif du refus.');
    final from = w.status == WithdrawalStatus.approved ? WithdrawalStatus.approved : WithdrawalStatus.pending;
    await _transition(w, from, {
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
      'rejectionReason': reason.trim(),
    });
    await _log('Retrait refusé', '${w.reference} · ${w.organisationName}', details: reason.trim());
    await _notify(w.ownerId, AppNotificationType.withdrawal, 'Retrait ${w.reference} refusé',
        'Motif : ${reason.trim()}. Le montant est de nouveau disponible sur votre solde.',
        positive: false);
  }

  // ---------------------------------------------------------------------
  // Paiements
  // ---------------------------------------------------------------------

  /// Tous les paiements (billets, votes, boosts), les plus récents
  /// d'abord. Les commandes de billets n'ont pas le nom de
  /// l'organisation : il est retrouvé via l'événement.
  Stream<List<AdminPayment>> watchPayments() {
    return _combineList([
      _db.collection('orders').snapshots(),
      _db.collection('voteOrders').snapshots(),
      _db.collection('eventBoosts').snapshots(),
      _events.snapshots(),
    ]).map((values) {
      final orders = values[0] as QuerySnapshot<Map<String, dynamic>>;
      final votes = values[1] as QuerySnapshot<Map<String, dynamic>>;
      final boosts = values[2] as QuerySnapshot<Map<String, dynamic>>;
      final events = values[3] as QuerySnapshot<Map<String, dynamic>>;
      final orgByEvent = {
        for (final d in events.docs) d.id: (d.data()['organisationName'] as String?) ?? '',
      };
      String method(dynamic raw) => raw == 'momo' ? 'MTN MoMo' : 'Orange Money';
      DateTime? date(dynamic raw) => raw is Timestamp ? raw.toDate() : null;

      final list = <AdminPayment>[
        for (final d in orders.docs)
          AdminPayment(
            id: d.id,
            kind: AdminPaymentKind.tickets,
            title: d.data()['eventTitle'] as String? ?? '',
            organisationName: orgByEvent[d.data()['eventId']] ?? '',
            buyerName: d.data()['buyerName'] as String? ?? '',
            amount: d.data()['totalAmount'] as num? ?? 0,
            status: d.data()['status'] as String? ?? 'pending',
            method: method(d.data()['paymentMethod']),
            date: date(d.data()['createdAt']),
          ),
        for (final d in votes.docs)
          AdminPayment(
            id: d.id,
            kind: AdminPaymentKind.votes,
            title: '${d.data()['campaignTitle'] ?? ''} · ${d.data()['candidateName'] ?? ''}',
            organisationName: d.data()['organisationName'] as String? ?? '',
            buyerName: d.data()['buyerName'] as String? ?? '',
            amount: d.data()['totalAmount'] as num? ?? 0,
            status: d.data()['status'] as String? ?? 'pending',
            method: method(d.data()['paymentMethod']),
            date: date(d.data()['createdAt']),
          ),
        for (final d in boosts.docs)
          AdminPayment(
            id: d.id,
            kind: AdminPaymentKind.boost,
            title: d.data()['eventTitle'] as String? ?? '',
            organisationName: orgByEvent[d.data()['eventId']] ?? '',
            buyerName: '',
            amount: d.data()['amount'] as num? ?? 0,
            status: d.data()['status'] as String? ?? 'confirmed',
            method: method(d.data()['paymentMethod']),
            date: date(d.data()['createdAt']),
          ),
      ]..sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
      return list;
    });
  }

  Stream<AdminDashboardData> watchDashboard() {
    return _combineList([
      watchPayments(),
      watchEvents(),
      watchCampaigns(),
      watchOrganisations(),
      watchWithdrawals(),
      _users.snapshots(),
    ]).map((v) => AdminDashboardData(
          payments: v[0] as List<AdminPayment>,
          events: v[1] as List<Event>,
          campaigns: v[2] as List<VoteCampaign>,
          organisations: v[3] as List<Organisation>,
          withdrawals: v[4] as List<Withdrawal>,
          userCount: (v[5] as QuerySnapshot<Map<String, dynamic>>).size,
        ));
  }

  // ---------------------------------------------------------------------
  // Tableau de bord
  // ---------------------------------------------------------------------

  Future<AdminStats> fetchStats() async {
    final results = await Future.wait([
      _users.get(),
      _moderation.get(),
      _organisations.get(),
      _events.where('status', isEqualTo: 'published').get(),
      _campaigns.where('status', isEqualTo: 'active').get(),
      _withdrawals.get(),
      _db.collection('orders').where('status', isEqualTo: 'confirmed').get(),
      _db.collection('voteOrders').where('status', isEqualTo: 'confirmed').get(),
      _db.collection('eventBoosts').get(),
    ]).timeout(const Duration(seconds: 40));

    final orgs = results[2].docs.map((d) => Organisation.fromMap(d.id, d.data())).toList();
    final withdrawals = results[5].docs.map((d) => Withdrawal.fromMap(d.id, d.data())).toList();
    final open = withdrawals.where((w) => w.isOpen);
    return AdminStats(
      users: results[0].size,
      blockedUsers: results[1].docs.where((d) => AccountModeration.fromMap(d.data()).blocked).length,
      organisations: orgs.length,
      certifiedOrganisations: orgs.where((o) => o.certified).length,
      certificationRequests: orgs.where((o) => o.certificationRequested && !o.certified).length,
      publishedEvents: results[3].size,
      activeCampaigns: results[4].size,
      pendingWithdrawals: open.length,
      pendingWithdrawalAmount: open.fold<num>(0, (s, w) => s + w.amount),
      paidWithdrawalAmount: withdrawals
          .where((w) => w.status == WithdrawalStatus.paid)
          .fold<num>(0, (s, w) => s + w.amount),
      ticketRevenue: results[6].docs.fold<num>(0, (s, d) => s + TicketOrder.fromMap(d.id, d.data()).totalAmount),
      voteRevenue: results[7].docs.fold<num>(0, (s, d) => s + VoteOrder.fromMap(d.id, d.data()).totalAmount),
      boostRevenue: results[8].docs.fold<num>(0, (s, d) => s + ((d.data()['amount'] as num?) ?? 0)),
    );
  }
}

/// Combine les dernières valeurs de plusieurs flux (émet dès que tous
/// ont produit une première valeur, puis à chaque nouvelle valeur).
Stream<List<Object?>> _combineList(List<Stream<Object?>> streams) {
  late StreamController<List<Object?>> controller;
  final values = List<Object?>.filled(streams.length, null);
  final has = List<bool>.filled(streams.length, false);
  final subs = <StreamSubscription<Object?>>[];
  controller = StreamController<List<Object?>>(
    onListen: () {
      for (var i = 0; i < streams.length; i++) {
        subs.add(streams[i].listen((v) {
          values[i] = v;
          has[i] = true;
          if (has.every((h) => h)) controller.add(List<Object?>.of(values));
        }, onError: controller.addError));
      }
    },
    onCancel: () async {
      for (final s in subs) {
        await s.cancel();
      }
    },
  );
  return controller.stream;
}

Stream<R> _combine3<A, B, C, R>(Stream<A> a, Stream<B> b, Stream<C> c, R Function(A, B, C) combine) =>
    _combineList([a, b, c]).map((v) => combine(v[0] as A, v[1] as B, v[2] as C));
