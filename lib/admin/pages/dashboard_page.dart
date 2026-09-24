import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/event.dart';
import '../../models/organisation.dart';
import '../../services/wallet_service.dart' show kPlatformCommissionRate;
import '../admin_service.dart';
import '../admin_shell.dart';
import '../admin_widgets.dart';
import 'payments_page.dart';

/// Tableau de bord, mis à jour en temps réel : actions à traiter,
/// chiffres clés, revenus mensuels, organisations et derniers paiements.
class DashboardPage extends StatelessWidget {
  final ValueChanged<AdminSection> onNavigate;

  const DashboardPage({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AdminDashboardData>(
      stream: AdminService.instance.watchDashboard(),
      builder: (context, snap) {
        if (snap.hasError) return AdminError(error: snap.error!);
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: AdminColors.primary));
        }
        final d = snap.data!;
        final openWithdrawals = d.withdrawals.where((w) => w.isOpen).toList();
        final certRequests = d.organisations.where((o) => o.certificationRequested && !o.certified).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            // À traiter
            _TodoCard(children: [
              _TodoRow(
                done: openWithdrawals.isEmpty,
                title: openWithdrawals.isEmpty
                    ? 'Aucun retrait en attente'
                    : 'Traiter ${openWithdrawals.length} demande(s) de retrait',
                subtitle: openWithdrawals.isEmpty
                    ? 'Toutes les demandes des organisations ont été traitées.'
                    : 'Montant total : ${formatXaf(openWithdrawals.fold<num>(0, (s, w) => s + w.amount))} · '
                        'la plus ancienne : ${openWithdrawals.first.reference}',
                onTap: () => onNavigate(AdminSection.withdrawals),
              ),
              _TodoRow(
                done: certRequests.isEmpty,
                title: certRequests.isEmpty
                    ? 'Aucune demande de certification'
                    : 'Examiner ${certRequests.length} demande(s) de certification',
                subtitle: certRequests.isEmpty
                    ? 'Les organisations certifiées peuvent retirer leurs gains.'
                    : certRequests.map((o) => o.name).take(3).join(', '),
                onTap: () => onNavigate(AdminSection.certifications),
              ),
            ]),
            const SizedBox(height: 26),
            // Chiffres clés
            LayoutBuilder(builder: (context, c) {
              final columns = c.maxWidth > 1000 ? 4 : 2;
              final w = (c.maxWidth - (columns - 1) * 14) / columns;
              final cards = [
                _StatCard(
                  label: 'Revenus nets',
                  value: formatXaf(d.platformRevenue),
                  hint: 'Commission ${(kPlatformCommissionRate * 100).round()}% + boosts',
                  icon: Icons.attach_money_rounded,
                  color: AdminColors.primary,
                  onTap: () => onNavigate(AdminSection.payments),
                ),
                _StatCard(
                  label: 'Événements',
                  value: '${d.events.length}',
                  hint: '${d.events.where((e) => e.status == EventStatus.published).length} publiés · créés au total',
                  icon: Icons.calendar_month_outlined,
                  color: AdminColors.primary,
                  onTap: () => onNavigate(AdminSection.events),
                ),
                _StatCard(
                  label: 'Votes',
                  value: '${d.campaigns.length}',
                  hint: 'Campagnes créées',
                  icon: Icons.emoji_events_outlined,
                  color: AdminColors.accent,
                  highlighted: true,
                  onTap: () => onNavigate(AdminSection.votes),
                ),
                _StatCard(
                  label: 'Organisations',
                  value: '${d.organisations.length}',
                  hint: '${d.organisations.where((o) => o.certified).length} certifiée(s) · ${d.userCount} utilisateurs',
                  icon: Icons.apartment_rounded,
                  color: AdminColors.ink,
                  onTap: () => onNavigate(AdminSection.organisations),
                ),
              ];
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [for (final card in cards) SizedBox(width: w, child: card)],
              );
            }),
            const SizedBox(height: 26),
            _MonthlyRevenueCard(months: d.monthlyVolume()),
            const SizedBox(height: 30),
            _SectionTitle('Organisations', onSeeAll: () => onNavigate(AdminSection.organisations)),
            const SizedBox(height: 12),
            _OrganisationCards(data: d),
            const SizedBox(height: 30),
            _SectionTitle('Derniers paiements', onSeeAll: () => onNavigate(AdminSection.payments)),
            const SizedBox(height: 12),
            if (d.payments.isEmpty)
              AdminCard(child: Text('Aucun paiement pour le moment.', style: adminText(13.5, color: AdminColors.muted)))
            else
              AdminPaymentsTable(payments: d.payments.take(8).toList()),
          ],
        );
      },
    );
  }
}

class _TodoCard extends StatelessWidget {
  final List<Widget> children;

  const _TodoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('À traiter', style: adminText(15, weight: FontWeight.w700)),
          const SizedBox(height: 12),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Ligne de tâche façon checklist : cochée et barrée quand c'est fait,
/// sinon encadrée en bleu avec une flèche.
class _TodoRow extends StatelessWidget {
  final bool done;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _TodoRow({required this.done, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: done ? Colors.white : AdminColors.field.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: done ? AdminColors.border : AdminColors.primary, width: done ? 1 : 1.3),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? AdminColors.success.withValues(alpha: 0.12) : AdminColors.primary,
                ),
                child: Icon(done ? Icons.check_rounded : Icons.radio_button_unchecked,
                    size: done ? 15 : 12, color: done ? AdminColors.success : Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: adminText(13, weight: FontWeight.w600, color: done ? AdminColors.muted : AdminColors.ink)),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: adminText(11.5, color: AdminColors.muted)),
                  ],
                ),
              ),
              if (!done) const Icon(Icons.arrow_forward_rounded, size: 18, color: AdminColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final IconData icon;
  final Color color;
  final bool highlighted;
  final VoidCallback onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    required this.color,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 120,
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: highlighted ? color.withValues(alpha: 0.35) : AdminColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(label, style: adminText(13, color: AdminColors.ink)),
                    ),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(8)),
                    child: Icon(icon, size: 19, color: color),
                  ),
                ],
              ),
              const Spacer(),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: adminText(21, weight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: adminText(11.5, color: AdminColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barres mensuelles (une seule série : pas de légende, le titre la
/// nomme ; infobulle au survol).
class _MonthlyRevenueCard extends StatelessWidget {
  final List<(DateTime, num)> months;

  const _MonthlyRevenueCard({required this.months});

  static double _niceMax(num max) {
    if (max <= 0) return 4;
    final raw = max * 1.15;
    final magnitude = [1, 2, 2.5, 5, 10];
    var base = 1.0;
    while (base * 10 <= raw) {
      base *= 10;
    }
    for (final m in magnitude) {
      if (base * m >= raw) return base * m;
    }
    return base * 10;
  }

  static String _compact(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(v % 1000000 == 0 ? 0 : 1)} M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)} k';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final monthFmt = DateFormat('MMM y', 'fr_FR');
    final maxY = _niceMax(months.fold<num>(0, (m, e) => e.$2 > m ? e.$2 : m));
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 22, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Revenus mensuels', style: adminText(14.5, weight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('Paiements confirmés (billets, votes, boosts) sur les 6 derniers mois',
              style: adminText(11.5, color: AdminColors.muted)),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                minY: 0,
                alignment: BarChartAlignment.spaceAround,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: AdminColors.border, strokeWidth: 1, dashArray: [4, 4]),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      interval: maxY / 4,
                      getTitlesWidget: (v, meta) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(_compact(v), textAlign: TextAlign.right, style: adminText(11, color: AdminColors.muted)),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < 0 || i >= months.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(monthFmt.format(months[i].$1), style: adminText(11.5, color: AdminColors.muted)),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AdminColors.ink,
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                      '${monthFmt.format(months[group.x].$1)}\n',
                      adminText(11.5, color: Colors.white70),
                      children: [
                        TextSpan(text: formatXaf(rod.toY), style: adminText(13, weight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < months.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: months[i].$2.toDouble(),
                          width: 34,
                          color: AdminColors.chart,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final VoidCallback onSeeAll;

  const _SectionTitle(this.title, {required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: adminText(15, weight: FontWeight.w600))),
        InkWell(
          onTap: onSeeAll,
          child: Row(
            children: [
              Text('Voir tout', style: adminText(12, weight: FontWeight.w600, color: AdminColors.accent)),
              const SizedBox(width: 3),
              const Icon(Icons.arrow_forward_rounded, size: 14, color: AdminColors.accent),
            ],
          ),
        ),
      ],
    );
  }
}

class _OrganisationCards extends StatelessWidget {
  final AdminDashboardData data;

  const _OrganisationCards({required this.data});

  @override
  Widget build(BuildContext context) {
    final orgs = [...data.organisations]..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    if (orgs.isEmpty) {
      return AdminCard(child: Text('Aucune organisation pour le moment.', style: adminText(13.5, color: AdminColors.muted)));
    }
    return LayoutBuilder(builder: (context, c) {
      final columns = c.maxWidth > 1100 ? 3 : 2;
      final w = (c.maxWidth - (columns - 1) * 14) / columns;
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          for (final o in orgs.take(columns * 2)) SizedBox(width: w, child: _OrganisationCard(organisation: o, data: data)),
        ],
      );
    });
  }
}

class _OrganisationCard extends StatelessWidget {
  final Organisation organisation;
  final AdminDashboardData data;

  const _OrganisationCard({required this.organisation, required this.data});

  @override
  Widget build(BuildContext context) {
    final o = organisation;
    final events = data.events.where((e) => e.organisationId == o.id).length;
    final votes = data.campaigns.where((c) => c.organisationId == o.id).length;
    final volume = data.confirmedPayments
        .where((p) => p.organisationName == o.name)
        .fold<num>(0, (s, p) => s + p.amount);
    Widget tile(IconData icon, String value, String label, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
            child: Column(
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(height: 4),
                Text(value, style: adminText(12.5, weight: FontWeight.w700)),
                Text(label, style: adminText(10, color: AdminColors.muted)),
              ],
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(o.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: adminText(14.5, weight: FontWeight.w600)),
              ),
              if (o.certified) ...[
                const SizedBox(width: 5),
                const Icon(Icons.verified, size: 15, color: AdminColors.info),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              if (o.blocked)
                const AdminChip(label: 'bloquée', color: AdminColors.danger)
              else if (o.certified)
                const AdminChip(label: 'certifiée', color: AdminColors.success)
              else if (o.certificationRequested)
                const AdminChip(label: 'certification demandée', color: AdminColors.warning)
              else
                const AdminChip(label: 'non certifiée', color: AdminColors.muted),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              tile(Icons.calendar_month_outlined, '$events', 'Événements', AdminColors.primary),
              const SizedBox(width: 8),
              tile(Icons.emoji_events_outlined, '$votes', 'Votes', AdminColors.accent),
              const SizedBox(width: 8),
              tile(Icons.account_balance_wallet_outlined, adminMoney.format(volume.round()), 'XAF', AdminColors.primary),
            ],
          ),
        ],
      ),
    );
  }
}
