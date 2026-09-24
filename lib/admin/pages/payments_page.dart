import 'package:flutter/material.dart';

import '../admin_service.dart';
import '../admin_widgets.dart';

enum _Kind { all, tickets, votes, boost }

/// Tous les paiements reçus : billets, votes et boosts.
class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  _Kind _kind = _Kind.all;
  bool _confirmedOnly = false;
  String _query = '';

  bool _ofKind(AdminPayment p, _Kind k) => switch (k) {
        _Kind.all => true,
        _Kind.tickets => p.kind == AdminPaymentKind.tickets,
        _Kind.votes => p.kind == AdminPaymentKind.votes,
        _Kind.boost => p.kind == AdminPaymentKind.boost,
      };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminPayment>>(
      stream: AdminService.instance.watchPayments(),
      builder: (context, snap) {
        final all = snap.data ?? const <AdminPayment>[];
        final q = _query.trim().toLowerCase();
        final list = all.where((p) {
          if (!_ofKind(p, _kind)) return false;
          if (_confirmedOnly && !p.confirmed) return false;
          if (q.isEmpty) return true;
          return p.reference.toLowerCase().contains(q) ||
              p.title.toLowerCase().contains(q) ||
              p.organisationName.toLowerCase().contains(q) ||
              p.buyerName.toLowerCase().contains(q);
        }).toList();
        final total = list.where((p) => p.confirmed).fold<num>(0, (s, p) => s + p.amount);
        return ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            AdminPageHeader(
              title: 'Paiements',
              subtitle: 'Billets, votes et boosts payés par Mobile Money',
              actions: [AdminSearchField(hint: 'Référence, organisation, acheteur…', onChanged: (v) => setState(() => _query = v))],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                children: [
                  Expanded(
                    child: AdminFilterTabs<_Kind>(
                      selected: _kind,
                      onSelected: (k) => setState(() => _kind = k),
                      tabs: [
                        for (final (k, label) in const [
                          (_Kind.all, 'Tous'),
                          (_Kind.tickets, 'Billets'),
                          (_Kind.votes, 'Votes'),
                          (_Kind.boost, 'Boosts'),
                        ])
                          (k, label, all.where((p) => _ofKind(p, k)).length),
                      ],
                    ),
                  ),
                  FilterChip(
                    selected: _confirmedOnly,
                    onSelected: (v) => setState(() => _confirmedOnly = v),
                    label: Text('Confirmés uniquement', style: adminText(12.5, weight: FontWeight.w600)),
                    selectedColor: AdminColors.success.withValues(alpha: 0.12),
                    checkmarkColor: AdminColors.success,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AdminColors.border),
                  ),
                  const SizedBox(width: 16),
                  Text('Total confirmé : ${formatXaf(total)}', style: adminText(14, weight: FontWeight.w800)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (snap.hasError)
              AdminError(error: snap.error!)
            else if (!snap.hasData)
              const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator()))
            else if (list.isEmpty)
              const AdminEmpty(icon: Icons.credit_card_off_outlined, text: 'Aucun paiement.')
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: AdminPaymentsTable(payments: list),
              ),
          ],
        );
      },
    );
  }
}

/// Tableau des paiements (réutilisé par le tableau de bord).
class AdminPaymentsTable extends StatelessWidget {
  final List<AdminPayment> payments;

  const AdminPaymentsTable({super.key, required this.payments});

  static (String, Color) status(AdminPayment p) => switch (p.status) {
        'confirmed' => ('Confirmé', AdminColors.success),
        'cancelled' => ('Annulé', AdminColors.muted),
        _ => ('En attente', AdminColors.warning),
      };

  static Color kindColor(AdminPaymentKind k) => switch (k) {
        AdminPaymentKind.tickets => AdminColors.primary,
        AdminPaymentKind.votes => AdminColors.accent,
        AdminPaymentKind.boost => AdminColors.warning,
      };

  Widget _header(String text, {int flex = 2, TextAlign align = TextAlign.left}) => Expanded(
        flex: flex,
        child: Text(text,
            textAlign: align,
            style: adminText(11, weight: FontWeight.w700, color: AdminColors.muted).copyWith(letterSpacing: 0.8)),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                _header('RÉFÉRENCE'),
                _header('TYPE', flex: 1),
                _header('ORGANISATION', flex: 3),
                _header('MONTANT', align: TextAlign.right),
                const SizedBox(width: 24),
                _header('STATUT'),
                _header('DATE'),
              ],
            ),
          ),
          for (final p in payments) ...[
            const Divider(height: 1, color: AdminColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: SelectableText(p.reference, style: adminText(13, weight: FontWeight.w700)),
                  ),
                  Expanded(
                    flex: 1,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AdminChip(label: p.kindLabel, color: kindColor(p.kind)),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.organisationName.isEmpty ? '—' : p.organisationName,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: adminText(13, weight: FontWeight.w600)),
                        Text(
                          [p.title, if (p.buyerName.isNotEmpty) 'par ${p.buyerName}'].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: adminText(11.5, color: AdminColors.muted),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(formatXaf(p.amount), textAlign: TextAlign.right, style: adminText(13, weight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AdminChip(label: status(p).$1, color: status(p).$2),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(p.date != null ? adminDate.format(p.date!) : '—',
                        style: adminText(12.5, color: AdminColors.muted)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
