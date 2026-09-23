import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/event.dart';
import '../models/order.dart';
import '../models/payment_method.dart';
import '../models/ticket.dart';
import '../models/ticket_type.dart';
import '../models/user_profile.dart';
import 'auth_service.dart';
import 'profile_service.dart';

/// Commandes de billets (collection `orders`) et billets individuels
/// (collection `tickets`), générés à la confirmation du paiement.
///
/// Aucune passerelle Orange Money / MTN Mobile Money réelle n'est
/// connectée : la commande est créée "en attente" puis confirmée via
/// [confirmOrder], qui simule l'accusé de réception d'un paiement mobile
/// money (voir [EventService.publish] et le flow d'achat pour le
/// contexte).
class OrderService {
  OrderService._();
  static final OrderService instance = OrderService._();

  static const _timeout = Duration(seconds: 15);

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _db.collection('orders');
  CollectionReference<Map<String, dynamic>> get _tickets =>
      _db.collection('tickets');
  CollectionReference<Map<String, dynamic>> _ticketTypes(String eventId) =>
      _db.collection('events').doc(eventId).collection('ticketTypes');
  CollectionReference<Map<String, dynamic>> _promoCodes(String eventId) =>
      _db.collection('events').doc(eventId).collection('promoCodes');

  String? get _uid => AuthService.instance.currentUser?.uid;

  // Toutes les requêtes sur `orders`, `tickets`, `voteOrders` et
  // `withdrawals` doivent filtrer sur `buyerId` ou `ownerId` : les règles
  // Firestore refusent sinon la requête en ligne (le cache hors ligne,
  // lui, ne vérifie pas les règles, d'où des données qui n'apparaissent
  // que sans connexion).

  /// Crée la commande en statut "pending". Ne touche à aucun stock : le
  /// stock n'est décrémenté qu'à la confirmation, pour ne jamais bloquer
  /// des billets sur une commande jamais payée.
  Future<String> createOrder({
    required Event event,
    required List<OrderItem> items,
    required PaymentMethod paymentMethod,
    required String paymentPhone,
    String? promoCode,
    required num totalAmount,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Utilisateur non connecté.');
    if (items.isEmpty) throw StateError('Aucun billet sélectionné.');

    final profile = await ProfileService.instance.fetchProfile(uid);
    final user = AuthService.instance.currentUser;
    final buyerName = _resolveName(profile, user?.displayName, user?.email);

    final doc = _orders.doc();
    final order = TicketOrder(
      id: doc.id,
      eventId: event.id,
      eventTitle: event.title,
      eventCoverImageUrl: event.coverImageUrl,
      eventVenue: event.venue,
      eventCity: event.city,
      ownerId: event.ownerId,
      buyerId: uid,
      buyerName: buyerName,
      items: items,
      totalAmount: totalAmount,
      paymentMethod: paymentMethod,
      paymentPhone: paymentPhone.trim(),
      promoCode: promoCode,
    );
    await doc.set(order.toMap()).timeout(_timeout);
    return doc.id;
  }

  String _resolveName(UserProfile? profile, String? displayName, String? email) {
    if (profile?.fullName.isNotEmpty == true) return profile!.fullName;
    if (displayName?.isNotEmpty == true) return displayName!;
    return email ?? 'Client';
  }

  /// Simule la confirmation du paiement mobile money : décrémente le
  /// stock des types de billets, incrémente l'usage du code promo
  /// éventuel, génère un [Ticket] par unité achetée puis marque la
  /// commande "confirmed". Tout se passe dans une transaction pour éviter
  /// de survendre un type de billet à stock limité.
  Future<List<Ticket>> confirmOrder(String orderId) async {
    final orderRef = _orders.doc(orderId);

    return _db.runTransaction<List<Ticket>>((tx) async {
      final orderSnap = await tx.get(orderRef);
      if (!orderSnap.exists) throw StateError('Commande introuvable.');
      final order = TicketOrder.fromMap(orderSnap.id, orderSnap.data()!);
      if (order.status == OrderStatus.confirmed) {
        // Déjà confirmée : renvoie les billets existants plutôt que d'en
        // regénérer (double-tap sur "Confirmer").
        final existing = await _tickets
            .where('buyerId', isEqualTo: order.buyerId)
            .where('orderId', isEqualTo: orderId)
            .get();
        return existing.docs
            .map((d) => Ticket.fromMap(d.id, d.data()))
            .toList();
      }

      // Vérifie et décrémente le stock de chaque type de billet.
      final typeRefs = {
        for (final item in order.items) item.ticketTypeId: _ticketTypes(order.eventId).doc(item.ticketTypeId),
      };
      final typeSnaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final entry in typeRefs.entries) {
        typeSnaps[entry.key] = await tx.get(entry.value);
      }
      for (final item in order.items) {
        final snap = typeSnaps[item.ticketTypeId];
        if (snap == null || !snap.exists) continue;
        final type = TicketType.fromMap(snap.id, snap.data()!);
        if (type.quantityTotal != null &&
            type.quantitySold + item.quantity > type.quantityTotal!) {
          throw StateError(
              'Stock insuffisant pour "${item.ticketTypeName}".');
        }
      }

      final tickets = <Ticket>[];
      final random = Random.secure();
      for (final item in order.items) {
        final typeRef = typeRefs[item.ticketTypeId];
        if (typeRef != null) {
          tx.update(typeRef, {'quantitySold': FieldValue.increment(item.quantity)});
        }
        for (var i = 0; i < item.quantity; i++) {
          final ticketRef = _tickets.doc();
          final code = _generateCode(random);
          final ticket = Ticket(
            id: ticketRef.id,
            orderId: order.id,
            eventId: order.eventId,
            eventTitle: order.eventTitle,
            eventCoverImageUrl: order.eventCoverImageUrl,
            ownerId: order.ownerId,
            venue: order.eventVenue,
            city: order.eventCity,
            seanceStart: item.seanceStart,
            seanceName: item.seanceName,
            ticketTypeId: item.ticketTypeId,
            ticketTypeName: item.ticketTypeName,
            price: item.unitPrice,
            buyerId: order.buyerId,
            buyerName: order.buyerName,
            code: code,
          );
          tx.set(ticketRef, ticket.toMap());
          tickets.add(ticket);
        }
      }

      if (order.promoCode != null) {
        tx.update(_promoCodes(order.eventId).doc(order.promoCode),
            {'usedCount': FieldValue.increment(1)});
      }

      tx.update(orderRef, {
        'status': 'confirmed',
        'confirmedAt': FieldValue.serverTimestamp(),
      });

      return tickets;
    }).timeout(const Duration(seconds: 20));
  }

  String _generateCode(Random random) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(10, (_) => chars[random.nextInt(chars.length)])
        .join();
  }

  // ---------------------------------------------------------------------
  // Lecture
  // ---------------------------------------------------------------------

  Stream<List<TicketOrder>> watchMyOrders() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _orders
        .where('buyerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => TicketOrder.fromMap(d.id, d.data())).toList())
        .handleError((_) => <TicketOrder>[]);
  }

  Future<TicketOrder?> fetchOrder(String orderId) async {
    final snap = await _orders.doc(orderId).get().timeout(_timeout);
    if (!snap.exists) return null;
    return TicketOrder.fromMap(snap.id, snap.data()!);
  }

  Stream<TicketOrder?> watchOrder(String orderId) {
    return _orders
        .doc(orderId)
        .snapshots()
        .map((d) => d.exists ? TicketOrder.fromMap(d.id, d.data()!) : null)
        .handleError((_) => null);
  }

  /// Billets d'une commande de l'utilisateur courant (QR codes).
  Stream<List<Ticket>> watchOrderTickets(String orderId) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _tickets
        .where('buyerId', isEqualTo: uid)
        .where('orderId', isEqualTo: orderId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Ticket.fromMap(d.id, d.data())).toList());
  }

  /// Billets vendus pour un événement (table "Billets & Vérification" du
  /// tableau de bord organisateur).
  Stream<List<Ticket>> watchEventTickets(String eventId) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    // Tri côté app : évite un index composite supplémentaire.
    return _tickets
        .where('ownerId', isEqualTo: uid)
        .where('eventId', isEqualTo: eventId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Ticket.fromMap(d.id, d.data()))
            .toList()
          ..sort((a, b) => (b.createdAt ?? DateTime(0))
              .compareTo(a.createdAt ?? DateTime(0))))
        .handleError((_) => <Ticket>[]);
  }

  /// Commandes confirmées d'un événement, pour la vue financière du
  /// tableau de bord organisateur.
  Stream<List<TicketOrder>> watchEventOrders(String eventId) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _orders
        .where('ownerId', isEqualTo: uid)
        .where('eventId', isEqualTo: eventId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => TicketOrder.fromMap(d.id, d.data())).toList())
        .handleError((_) => <TicketOrder>[]);
  }

  /// Recherche un billet de l'événement par son code (scan à l'entrée).
  /// Le filtre `ownerId` est obligatoire : les règles Firestore ne
  /// laissent l'organisateur lire que les billets de ses événements, et
  /// refusent toute requête qui ne le garantit pas.
  Future<Ticket?> findTicketByCode(String eventId, String code) async {
    final uid = _uid;
    if (uid == null) throw StateError('Utilisateur non connecté.');
    final snap = await _tickets
        .where('ownerId', isEqualTo: uid)
        .where('eventId', isEqualTo: eventId)
        .where('code', isEqualTo: code.trim().toUpperCase())
        .limit(1)
        .get()
        .timeout(_timeout);
    if (snap.docs.isEmpty) return null;
    return Ticket.fromMap(snap.docs.first.id, snap.docs.first.data());
  }

  /// Marque un billet comme scanné (check-in à l'entrée). Renvoie `false`
  /// si le billet est invalide, annulé ou déjà utilisé.
  Future<bool> checkIn(String ticketId) async {
    final ref = _tickets.doc(ticketId);
    return _db.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return false;
      final ticket = Ticket.fromMap(snap.id, snap.data()!);
      if (ticket.status != TicketStatus.valid) return false;
      tx.update(ref, {
        'status': 'used',
        'checkedInAt': FieldValue.serverTimestamp(),
      });
      return true;
    }).timeout(_timeout);
  }
}
