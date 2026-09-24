import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/payment_method.dart';
import '../../models/withdrawal.dart';
import '../../services/wallet_service.dart';
import '../admin_service.dart';
import '../admin_widgets.dart';

enum _Filter { todo, pending, approved, paid, rejected, cancelled, all }

/// Demandes de retrait des organisations, traitées strictement dans
/// l'ordre d'arrivée : seule la plus ancienne demande en attente peut
/// être validée ; une demande validée est ensuite marquée payée avec la
/// référence de la transaction Mobile Money.
class WithdrawalsPage extends StatefulWidget {
  const WithdrawalsPage({super.key});

  @override
  State<WithdrawalsPage> createState() => _WithdrawalsPageState();
}

class _WithdrawalsPageState extends State<WithdrawalsPage> {
  _Filter _filter = _Filter.todo;
  String _query = '';

  bool _matches(Withdrawal w) {
    final okFilter = switch (_filter) {
      _Filter.todo => w.isOpen,
      _Filter.pending => w.status == WithdrawalStatus.pending,
      _Filter.approved => w.status == WithdrawalStatus.approved,
      _Filter.paid => w.status == WithdrawalStatus.paid,
      _Filter.rejected => w.status == WithdrawalStatus.rejected,
      _Filter.cancelled => w.status == WithdrawalStatus.cancelled,
      _Filter.all => true,
    };
    if (!okFilter) return false;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return w.reference.toLowerCase().contains(q) ||
        w.organisationName.toLowerCase().contains(q) ||
        w.phone.contains(q) ||
        (w.transactionRef?.toLowerCase().contains(q) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Withdrawal>>(
      stream: AdminService.instance.watchWithdrawals(),
      builder: (context, snap) {
        final all = snap.data ?? const <Withdrawal>[];
        final pendingQueue = all.where((w) => w.status == WithdrawalStatus.pending).toList();
        int count(bool Function(Withdrawal) test) => all.where(test).length;
        var list = all.where(_matches).toList();
        // Historique (payés, refusés, tous...) : plus récents d'abord.
        if (_filter != _Filter.todo && _filter != _Filter.pending && _filter != _Filter.approved) {
          list = list.reversed.toList();
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            AdminPageHeader(
              title: 'Retraits',
              subtitle: "Demandes des organisations certifiées · traitées dans l'ordre d'arrivée",
              actions: [AdminSearchField(hint: 'Référence, organisation, numéro…', onChanged: (v) => setState(() => _query = v))],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: AdminFilterTabs<_Filter>(
                selected: _filter,
                onSelected: (f) => setState(() => _filter = f),
                tabs: [
                  (_Filter.todo, 'À traiter', count((w) => w.isOpen)),
                  (_Filter.pending, 'En attente', count((w) => w.status == WithdrawalStatus.pending)),
                  (_Filter.approved, 'Validés · à payer', count((w) => w.status == WithdrawalStatus.approved)),
                  (_Filter.paid, 'Payés', count((w) => w.status == WithdrawalStatus.paid)),
                  (_Filter.rejected, 'Refusés', count((w) => w.status == WithdrawalStatus.rejected)),
                  (_Filter.cancelled, 'Annulés', count((w) => w.status == WithdrawalStatus.cancelled)),
                  (_Filter.all, 'Tous', all.length),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (snap.hasError)
              AdminError(error: snap.error!)
            else if (!snap.hasData)
              const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator()))
            else if (list.isEmpty)
              const AdminEmpty(icon: Icons.inbox_outlined, text: 'Aucune demande dans cette liste.')
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    for (final w in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _WithdrawalCard(
                          withdrawal: w,
                          queuePosition: w.status == WithdrawalStatus.pending ? pendingQueue.indexOf(w) + 1 : null,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _WithdrawalCard extends StatelessWidget {
  final Withdrawal withdrawal;

  /// Position dans la file des demandes en attente (1 = la prochaine).
  final int? queuePosition;

  const _WithdrawalCard({required this.withdrawal, this.queuePosition});

  static Color statusColor(WithdrawalStatus s) => switch (s) {
        WithdrawalStatus.pending => AdminColors.warning,
        WithdrawalStatus.approved => AdminColors.info,
        WithdrawalStatus.paid => AdminColors.success,
        WithdrawalStatus.rejected => AdminColors.danger,
        WithdrawalStatus.cancelled => AdminColors.muted,
      };

  Future<void> _showBalance(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Solde de ${withdrawal.organisationName}', style: adminText(17, weight: FontWeight.w700)),
        content: SizedBox(
          width: 420,
          child: FutureBuilder<WalletSummary>(
            future: AdminService.instance.fetchBalance(withdrawal),
            builder: (ctx, snap) {
              if (snap.hasError) return Text('Erreur : ${snap.error}', style: adminText(13, color: AdminColors.danger));
              if (!snap.hasData) {
                return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
              }
              final s = snap.data!;
              // Le montant demandé est inclus dans "en attente" : on le
              // remet pour savoir s'il est couvert par les gains.
              final coverable = s.availableBalance + withdrawal.amount;
              final ok = !withdrawal.isOpen || coverable >= withdrawal.amount;
              Widget row(String l, String v, {bool bold = false}) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      Expanded(child: Text(l, style: adminText(13, color: AdminColors.muted))),
                      Text(v, style: adminText(13.5, weight: bold ? FontWeight.w800 : FontWeight.w600)),
                    ]),
                  );
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  row('Recettes brutes', formatXaf(s.grossRevenue)),
                  row('Commission plateforme', '-${formatXaf(s.commission)}'),
                  row('Net organisateur', formatXaf(s.netRevenue), bold: true),
                  row('Déjà payé', '-${formatXaf(s.withdrawn)}'),
                  row('Demandes en cours (dont celle-ci)', '-${formatXaf(s.pendingWithdrawals)}'),
                  const Divider(height: 24),
                  row('Solde restant', formatXaf(s.availableBalance), bold: true),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (ok ? AdminColors.success : AdminColors.danger).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      ok
                          ? 'Les gains couvrent le montant demandé (${formatXaf(withdrawal.amount)}).'
                          : 'Attention : les gains ne couvrent pas ce retrait.',
                      style: adminText(13, weight: FontWeight.w600, color: ok ? AdminColors.success : AdminColors.danger),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer'))],
      ),
    );
  }

  Future<void> _approve(BuildContext context) async {
    final ok = await adminConfirm(context,
        title: 'Valider ${withdrawal.reference} ?',
        message: 'Vous allez envoyer ${formatXaf(withdrawal.amount)} à ${withdrawal.organisationName} '
            'sur le ${paymentMethodLabel(withdrawal.paymentMethod)} ${withdrawal.phone}. '
            "Une fois l'envoi fait, marquez la demande comme payée avec la référence de la transaction.",
        confirmLabel: 'Valider la demande',
        color: AdminColors.info);
    if (!ok || !context.mounted) return;
    await runAdminAction(context, () => AdminService.instance.approveWithdrawal(withdrawal),
        success: '${withdrawal.reference} validé. Procédez au paiement.');
  }

  Future<void> _markPaid(BuildContext context) async {
    final ref = await adminPrompt(context,
        title: 'Confirmer le paiement de ${withdrawal.reference}',
        message: 'Montant envoyé : ${formatXaf(withdrawal.amount)} au ${withdrawal.phone} '
            '(${paymentMethodLabel(withdrawal.paymentMethod)}).',
        fieldLabel: 'Référence de la transaction Mobile Money',
        confirmLabel: 'Marquer comme payé',
        color: AdminColors.success);
    if (ref == null || !context.mounted) return;
    await runAdminAction(context, () => AdminService.instance.markWithdrawalPaid(withdrawal, ref),
        success: '${withdrawal.reference} marqué payé.');
  }

  Future<void> _reject(BuildContext context) async {
    final reason = await adminPrompt(context,
        title: 'Refuser ${withdrawal.reference}',
        message: "Le motif sera visible par l'organisateur dans son portefeuille. Le montant redevient disponible sur son solde.",
        fieldLabel: 'Motif du refus',
        confirmLabel: 'Refuser',
        color: AdminColors.danger);
    if (reason == null || !context.mounted) return;
    await runAdminAction(context, () => AdminService.instance.rejectWithdrawal(withdrawal, reason),
        success: '${withdrawal.reference} refusé.');
  }

  @override
  Widget build(BuildContext context) {
    final w = withdrawal;
    final color = statusColor(w.status);
    final isNext = queuePosition == 1;
    final timeline = <(String, DateTime?)>[
      ('Demandé', w.createdAt),
      if (w.approvedAt != null) ('Validé', w.approvedAt),
      if (w.paidAt != null) ('Payé', w.paidAt),
      if (w.rejectedAt != null) ('Refusé', w.rejectedAt),
      if (w.cancelledAt != null) ('Annulé', w.cancelledAt),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isNext ? AdminColors.warning : AdminColors.border, width: isNext ? 1.6 : 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Référence + position
          SizedBox(
            width: 130,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.reference, style: adminText(14, weight: FontWeight.w800)),
                const SizedBox(height: 6),
                AdminChip(label: withdrawalStatusLabel(w.status), color: color),
                if (queuePosition != null) ...[
                  const SizedBox(height: 6),
                  Text(isNext ? '▶ Prochain à traiter' : 'Position $queuePosition dans la file',
                      style: adminText(11.5,
                          weight: FontWeight.w600, color: isNext ? AdminColors.warning : AdminColors.muted)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Organisation + paiement
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.organisationName, style: adminText(15, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('${paymentMethodLabel(w.paymentMethod)} · ', style: adminText(13, color: AdminColors.muted)),
                    SelectableText(w.phone, style: adminText(13, weight: FontWeight.w600)),
                    IconButton(
                      tooltip: 'Copier le numéro',
                      visualDensity: VisualDensity.compact,
                      iconSize: 16,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: w.phone));
                        adminToast(context, 'Numéro copié.');
                      },
                      icon: const Icon(Icons.copy_rounded, color: AdminColors.muted),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    for (final (label, date) in timeline)
                      Text('$label : ${date != null ? adminDate.format(date) : '—'}',
                          style: adminText(12, color: AdminColors.muted)),
                  ],
                ),
                if (w.transactionRef?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text('Réf. transaction : ${w.transactionRef}',
                      style: adminText(12, weight: FontWeight.w600, color: AdminColors.success)),
                ],
                if (w.rejectionReason?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text('Motif du refus : ${w.rejectionReason}',
                      style: adminText(12, weight: FontWeight.w600, color: AdminColors.danger)),
                ],
              ],
            ),
          ),
          // Montant
          SizedBox(
            width: 150,
            child: Text(formatXaf(w.amount), textAlign: TextAlign.right, style: adminText(18, weight: FontWeight.w800)),
          ),
          const SizedBox(width: 20),
          // Actions
          SizedBox(
            width: 230,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                AdminActionButton(label: 'Solde', icon: Icons.account_balance_wallet_outlined, onPressed: () => _showBalance(context)),
                if (w.status == WithdrawalStatus.pending)
                  Tooltip(
                    message: isNext ? '' : "Traitez d'abord les demandes plus anciennes.",
                    child: AdminActionButton(
                      label: 'Valider',
                      icon: Icons.check_rounded,
                      color: AdminColors.info,
                      filled: true,
                      onPressed: isNext ? () => _approve(context) : null,
                    ),
                  ),
                if (w.status == WithdrawalStatus.approved)
                  AdminActionButton(
                    label: 'Marquer payé',
                    icon: Icons.done_all_rounded,
                    color: AdminColors.success,
                    filled: true,
                    onPressed: () => _markPaid(context),
                  ),
                if (w.isOpen)
                  AdminActionButton(
                    label: 'Refuser',
                    icon: Icons.close_rounded,
                    color: AdminColors.danger,
                    onPressed: () => _reject(context),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
