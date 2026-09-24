import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/organisation.dart';
import '../models/payment_method.dart';
import '../models/withdrawal.dart';
import '../services/organisation_service.dart';
import '../services/wallet_service.dart';
import '../widgets/auth_widgets.dart'
    show authPrimary, authInk, authMuted, authBorder, showAuthSnack;

/// Portefeuille d'une organisation : solde (recettes de ses événements
/// moins commission plateforme et retraits déjà effectués/en attente) et
/// demandes de retrait Mobile Money. Accessible depuis le tableau de
/// bord de l'organisation.
class WalletScreen extends StatefulWidget {
  final Organisation organisation;

  const WalletScreen({super.key, required this.organisation});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late Future<WalletSummary> _summaryFuture;
  late Future<List<WalletTransaction>> _transactionsFuture;

  StreamSubscription<List<Withdrawal>>? _withdrawalsSub;

  @override
  void initState() {
    super.initState();
    _summaryFuture = WalletService.instance.fetchSummary(widget.organisation.id);
    _transactionsFuture = WalletService.instance.fetchTransactions(widget.organisation.id);
    // Temps réel : dès que l'administrateur valide, paie ou refuse une
    // demande, le solde est recalculé sans quitter l'écran.
    var first = true;
    _withdrawalsSub = WalletService.instance.watchWithdrawals(widget.organisation.id).listen((_) {
      if (first) {
        first = false;
        return;
      }
      if (mounted) _refresh();
    });
  }

  @override
  void dispose() {
    _withdrawalsSub?.cancel();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _summaryFuture = WalletService.instance.fetchSummary(widget.organisation.id);
      _transactionsFuture = WalletService.instance.fetchTransactions(widget.organisation.id);
    });
  }

  Future<void> _openWithdrawSheet(Organisation organisation, WalletSummary summary) async {
    final requested = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _WithdrawSheet(organisation: organisation, summary: summary),
    );
    if (requested == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FA),
        elevation: 0,
        foregroundColor: authInk,
        title: Text('Portefeuille', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: authInk)),
      ),
      body: SafeArea(
        child: StreamBuilder<Organisation?>(
          stream: OrganisationService.instance.watchOne(widget.organisation.id),
          builder: (context, orgSnap) {
            final organisation = orgSnap.data ?? widget.organisation;
            return RefreshIndicator(
          color: authPrimary,
          onRefresh: () async => _refresh(),
          child: FutureBuilder<WalletSummary>(
            future: _summaryFuture,
            builder: (context, snapshot) {
              final summary = snapshot.data ?? WalletSummary.empty;
              final loading = snapshot.connectionState == ConnectionState.waiting;
              final error = snapshot.hasError ? snapshot.error : null;
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  if (error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: authPrimary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: authPrimary.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: authPrimary, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('Impossible de charger le solde. Vérifiez votre connexion puis réessayez.',
                                style: GoogleFonts.nunito(fontSize: 12, color: authInk)),
                          ),
                          TextButton(
                            onPressed: _refresh,
                            child: Text('Réessayer', style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w700, color: authPrimary)),
                          ),
                        ],
                      ),
                    ),
                  _CertificationBanner(organisation: organisation),
                  _BalanceCard(
                    organisation: organisation,
                    summary: summary,
                    loading: loading,
                    onWithdraw: loading || error != null || !organisation.certified || organisation.blocked
                        ? null
                        : () => _openWithdrawSheet(organisation, summary),
                  ),
                  const SizedBox(height: 26),
                  Text('Toutes les transactions',
                      style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: authInk)),
                  Text('Chaque vente de billet ou achat de vote confirmé, avec la part qui vous revient.',
                      style: GoogleFonts.nunito(fontSize: 12, color: authMuted)),
                  const SizedBox(height: 12),
                  FutureBuilder<List<WalletTransaction>>(
                    future: _transactionsFuture,
                    builder: (context, tSnap) {
                      if (!tSnap.hasData) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: CircularProgressIndicator(color: authPrimary)),
                        );
                      }
                      final transactions = tSnap.data!;
                      if (transactions.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: authBorder),
                          ),
                          child: Text('Aucune transaction pour le moment.',
                              style: GoogleFonts.nunito(fontSize: 13, color: authMuted)),
                        );
                      }
                      return Column(
                        children: transactions.map((t) => _TransactionTile(transaction: t)).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 26),
                  Text('Historique des retraits',
                      style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: authInk)),
                  const SizedBox(height: 12),
                  StreamBuilder<List<Withdrawal>>(
                    stream: WalletService.instance.watchWithdrawals(widget.organisation.id),
                    builder: (context, wSnap) {
                      final withdrawals = wSnap.data ?? const <Withdrawal>[];
                      if (!wSnap.hasData) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: CircularProgressIndicator(color: authPrimary)),
                        );
                      }
                      if (withdrawals.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: authBorder),
                          ),
                          child: Text('Aucune demande de retrait pour le moment.',
                              style: GoogleFonts.nunito(fontSize: 13, color: authMuted)),
                        );
                      }
                      return Column(
                        children: withdrawals
                            .map((w) => _WithdrawalTile(withdrawal: w, onCancelled: _refresh))
                            .toList(),
                      );
                    },
                  ),
                ],
              );
            },
          ),
            );
          },
        ),
      ),
    );
  }
}

/// Statut de certification de l'organisation : obligatoire pour retirer.
class _CertificationBanner extends StatefulWidget {
  final Organisation organisation;

  const _CertificationBanner({required this.organisation});

  @override
  State<_CertificationBanner> createState() => _CertificationBannerState();
}

class _CertificationBannerState extends State<_CertificationBanner> {
  bool _sending = false;

  Future<void> _request() async {
    setState(() => _sending = true);
    try {
      await OrganisationService.instance.requestCertification(widget.organisation.id);
      if (mounted) showAuthSnack(context, "Demande de certification envoyée à l'administrateur.");
    } catch (_) {
      if (mounted) showAuthSnack(context, "Échec de l'envoi de la demande.");
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.organisation;
    final Color color;
    final IconData icon;
    final String title;
    final String text;
    Widget? action;
    if (o.blocked) {
      color = const Color(0xFFD93A3A);
      icon = Icons.block;
      title = 'Organisation bloquée';
      text = o.blockedReason?.isNotEmpty == true
          ? 'Motif : ${o.blockedReason}. Contactez le support.'
          : "Les retraits et publications sont suspendus. Contactez le support.";
    } else if (o.certified) {
      color = const Color(0xFF1E9E6B);
      icon = Icons.verified;
      title = 'Organisation certifiée';
      text = "Vos demandes de retrait sont traitées par l'administrateur, dans l'ordre d'arrivée.";
    } else if (o.certificationRequested) {
      color = const Color(0xFFB98900);
      icon = Icons.hourglass_top_rounded;
      title = 'Certification en cours d\'examen';
      text = "L'administrateur vérifie votre organisation. Les retraits seront possibles dès la certification.";
    } else {
      color = const Color(0xFF0F2A6B);
      icon = Icons.verified_outlined;
      title = 'Certification requise pour retirer';
      text = "Pour recevoir vos gains, faites certifier votre organisation par l'administrateur.";
      action = Padding(
        padding: const EdgeInsets.only(top: 10),
        child: SizedBox(
          height: 38,
          child: ElevatedButton(
            onPressed: _sending ? null : _request,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_sending ? 'Envoi…' : 'Demander la certification',
                style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: authInk)),
                const SizedBox(height: 2),
                Text(text, style: GoogleFonts.nunito(fontSize: 12, color: authMuted)),
                ?action,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final WalletTransaction transaction;

  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern('fr_FR');
    final dateFmt = DateFormat('d MMM y • HH:mm', 'fr_FR');
    final isVote = transaction.type == 'Vote';
    final color = isVote ? const Color(0xFF6B4FBB) : const Color(0xFF1E9E6B);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: authBorder), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(12)),
            child: Icon(isVote ? Icons.how_to_vote_outlined : Icons.confirmation_number_outlined, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(transaction.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(fontSize: 13.5, fontWeight: FontWeight.w700, color: authInk)),
                const SizedBox(height: 2),
                Text(
                  '${transaction.type}${transaction.date != null ? ' · ${dateFmt.format(transaction.date!)}' : ''}',
                  style: GoogleFonts.nunito(fontSize: 11.5, color: authMuted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('+${fmt.format(transaction.grossAmount)} XAF',
                  style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: authInk)),
              const SizedBox(height: 2),
              Text('dont ${fmt.format(transaction.netAmount)} XAF net',
                  style: GoogleFonts.nunito(fontSize: 10.5, color: authMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final Organisation organisation;
  final WalletSummary summary;
  final bool loading;
  final VoidCallback? onWithdraw;

  const _BalanceCard({
    required this.organisation,
    required this.summary,
    required this.loading,
    required this.onWithdraw,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern('fr_FR');
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: authInk,
        boxShadow: [
          BoxShadow(color: authInk.withOpacity(0.25), blurRadius: 24, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(organisation.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 14),
          Text('Solde disponible', style: GoogleFonts.nunito(fontSize: 12.5, color: Colors.white70)),
          const SizedBox(height: 4),
          loading
              ? const SizedBox(
                  height: 34,
                  child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)))
              : Text('${fmt.format(summary.availableBalance)} XAF',
                  style: GoogleFonts.nunito(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                _statRow('Recettes brutes', '${fmt.format(summary.grossRevenue)} XAF'),
                const SizedBox(height: 8),
                _statRow('Commission plateforme (${(kPlatformCommissionRate * 100).toStringAsFixed(0)}%)',
                    '-${fmt.format(summary.commission)} XAF'),
                const SizedBox(height: 8),
                _statRow('Déjà retiré', '-${fmt.format(summary.withdrawn)} XAF'),
                if (summary.pendingWithdrawals > 0) ...[
                  const SizedBox(height: 8),
                  _statRow('En attente de traitement', '-${fmt.format(summary.pendingWithdrawals)} XAF'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: summary.availableBalance <= 0 ? null : onWithdraw,
              icon: Icon(organisation.certified ? Icons.arrow_upward_rounded : Icons.lock_outline, size: 18),
              label: Text(organisation.certified ? 'Demander un retrait' : 'Certification requise', style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0F2A6B),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Row(
      children: [
        Expanded(child: Text(label, style: GoogleFonts.nunito(fontSize: 12, color: Colors.white70))),
        Text(value, style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
      ],
    );
  }
}

class _WithdrawSheet extends StatefulWidget {
  final Organisation organisation;
  final WalletSummary summary;

  const _WithdrawSheet({required this.organisation, required this.summary});

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  final _amountCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  PaymentMethod _method = PaymentMethod.orangeMoney;
  bool _submitting = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = num.tryParse(_amountCtrl.text.trim().replaceAll(' ', ''));
    if (amount == null || amount <= 0) {
      showAuthSnack(context, 'Entrez un montant valide.');
      return;
    }
    if (_phoneCtrl.text.trim().length < 8) {
      showAuthSnack(context, 'Entrez un numéro de téléphone valide.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await WalletService.instance.requestWithdrawal(
        organisation: widget.organisation,
        amount: amount,
        paymentMethod: _method,
        phone: _phoneCtrl.text.trim(),
      );
      if (!mounted) return;
      showAuthSnack(context, "Demande envoyée à l'administrateur. Vous serez payé après validation.");
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showAuthSnack(context, e is StateError ? e.message : 'Échec de la demande de retrait.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern('fr_FR');
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: authBorder, borderRadius: BorderRadius.circular(4))),
          ),
          const SizedBox(height: 18),
          Text('Demander un retrait', style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w700, color: authInk)),
          const SizedBox(height: 4),
          Text('Solde disponible : ${fmt.format(widget.summary.availableBalance)} XAF',
              style: GoogleFonts.nunito(fontSize: 12.5, color: authMuted)),
          const SizedBox(height: 20),
          Text('Montant (XAF)', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: authInk)),
          const SizedBox(height: 8),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            style: GoogleFonts.nunito(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Ex. 50000',
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: authBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: authBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: authPrimary, width: 1.4)),
            ),
          ),
          const SizedBox(height: 18),
          Text('Moyen de réception', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: authInk)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MethodChip(
                  label: 'Orange Money',
                  color: const Color(0xFFFF7900),
                  selected: _method == PaymentMethod.orangeMoney,
                  onTap: () => setState(() => _method = PaymentMethod.orangeMoney),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MethodChip(
                  label: 'MTN MoMo',
                  color: const Color(0xFFFFCC00),
                  selected: _method == PaymentMethod.mtnMomo,
                  onTap: () => setState(() => _method = PaymentMethod.mtnMomo),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Numéro ${paymentMethodLabel(_method)}', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: authInk)),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.nunito(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Ex. 6XX XX XX XX',
              prefixIcon: const Icon(Icons.phone_outlined, size: 20, color: authMuted),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: authBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: authBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: authPrimary, width: 1.4)),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: authPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _submitting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Text('Envoyer la demande', style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _MethodChip({required this.label, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.10) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : authBorder, width: selected ? 1.6 : 1),
        ),
        child: Column(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: const Icon(Icons.phone_iphone, size: 15, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(label, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: authInk)),
          ],
        ),
      ),
    );
  }
}

class _WithdrawalTile extends StatelessWidget {
  final Withdrawal withdrawal;
  final VoidCallback onCancelled;

  const _WithdrawalTile({required this.withdrawal, required this.onCancelled});

  static const _colors = {
    WithdrawalStatus.pending: Color(0xFFB98900),
    WithdrawalStatus.approved: Color(0xFF2D6BE0),
    WithdrawalStatus.paid: Color(0xFF1E9E6B),
    WithdrawalStatus.rejected: authPrimary,
    WithdrawalStatus.cancelled: authMuted,
  };

  Future<void> _cancel(BuildContext context) async {
    try {
      await WalletService.instance.cancelWithdrawal(withdrawal.id);
      onCancelled();
    } catch (_) {
      if (context.mounted) showAuthSnack(context, "Échec de l'annulation.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern('fr_FR');
    final dateFmt = DateFormat('d MMM y • HH:mm', 'fr_FR');
    final color = _colors[withdrawal.status]!;
    final w = withdrawal;
    String? detail;
    switch (w.status) {
      case WithdrawalStatus.pending:
        detail = "En file d'attente chez l'administrateur.";
      case WithdrawalStatus.approved:
        detail = w.approvedAt != null ? 'Validé le ${dateFmt.format(w.approvedAt!)} · envoi en cours.' : 'Validé · envoi en cours.';
      case WithdrawalStatus.paid:
        detail = [
          if (w.paidAt != null) 'Payé le ${dateFmt.format(w.paidAt!)}',
          if (w.transactionRef?.isNotEmpty == true) 'Réf. ${w.transactionRef}',
        ].join(' · ');
      case WithdrawalStatus.rejected:
        detail = w.rejectionReason?.isNotEmpty == true ? 'Motif : ${w.rejectionReason}' : null;
      case WithdrawalStatus.cancelled:
        detail = null;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: authBorder), borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.arrow_upward_rounded, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.reference,
                    style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: authMuted, letterSpacing: 0.4)),
                Text('${fmt.format(w.amount)} XAF',
                    style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: authInk)),
                const SizedBox(height: 2),
                Text(
                  '${paymentMethodLabel(w.paymentMethod)} · ${w.phone}'
                  '${w.createdAt != null ? ' · ${dateFmt.format(w.createdAt!)}' : ''}',
                  style: GoogleFonts.nunito(fontSize: 11.5, color: authMuted),
                ),
                if (detail != null && detail.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(detail, style: GoogleFonts.nunito(fontSize: 11.5, fontWeight: FontWeight.w500, color: color)),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
                child: Text(withdrawalStatusLabel(w.status),
                    style: GoogleFonts.nunito(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
              ),
              if (w.status == WithdrawalStatus.pending) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _cancel(context),
                  child: Text('Annuler', style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w600, color: authPrimary)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
