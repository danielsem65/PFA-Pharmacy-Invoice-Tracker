import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/design.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/payment.dart';
import '../../models/supplier_invoice.dart';
import '../../widgets/aurora_background.dart';
import '../../widgets/glass_panel.dart';
import '../../widgets/page_header.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/ui_kit.dart';
import '../invoices/invoices_controller.dart';
import '../payments/payments_controller.dart';
import '../products/products_controller.dart';
import '../suppliers/suppliers_controller.dart';
import 'overview_controller.dart';

/// The page the app opens on: what is owed, what is late, what has been paid,
/// and which suppliers the money is sitting with.
class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(invoicesProvider);
    final payments = ref.watch(paymentsProvider);
    final suppliers = ref.watch(suppliersProvider);
    final products = ref.watch(productsProvider);
    final now = DateTime.now();

    final summary = summarise(
      invoices: invoices,
      payments: payments,
      supplierCount: suppliers.length,
      productCount: products.length,
      now: now,
    );
    final trend = monthlyTrend(
      invoices: invoices,
      payments: payments,
      now: now,
    );
    final shares = supplierShares(
      invoices: invoices,
      suppliers: suppliers,
      now: now,
    );
    final late = needsAttention(invoices: invoices, now: now);

    String nameOf(String id) {
      for (final s in suppliers) {
        if (s.id == id) return s.name;
      }
      return 'Unknown supplier';
    }

    final recent = [...payments]
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: Insets.page,
            child: PageHeader(
              title: _greeting(now),
              subtitle:
                  '${DateFormat('EEEE, d MMMM yyyy').format(now)} · what the books look like today',
              icon: Icons.grid_view_rounded,
              accentIndex: 0,
              actions: <Widget>[
                OutlinedButton.icon(
                  onPressed: () => context.go('/payments/new'),
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('Record payment'),
                ),
                FilledButton.icon(
                  onPressed: () => context.go('/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('New Invoice'),
                ),
              ],
            ),
          ),
          Expanded(
            child: summary.isEmpty
                ? EmptyState(
                    icon: Icons.auto_graph_rounded,
                    title: 'Nothing to summarise yet',
                    message:
                        'Add a supplier and record your first invoice. This page '
                        'will then show what is owed, what is late, and what has '
                        'been paid, month by month.',
                    action: FilledButton.icon(
                      onPressed: () => context.go('/new'),
                      icon: const Icon(Icons.add),
                      label: const Text('Add invoice'),
                    ),
                    secondary: OutlinedButton.icon(
                      onPressed: () => context.go('/suppliers/new'),
                      icon: const Icon(Icons.local_shipping_outlined, size: 18),
                      label: const Text('Add supplier'),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _KpiRow(summary: summary),
                        const SizedBox(height: 16),
                        _WideRow(
                          left: _TrendPanel(
                            trend: trend,
                            invoicedTotal: summary.invoicedTotal,
                            paidTotal: summary.paidTotal,
                          ),
                          right: _AttentionPanel(
                            invoices: late,
                            now: now,
                            nameOf: nameOf,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _WideRow(
                          left: _SupplierPanel(
                            shares: shares,
                            total: summary.outstanding,
                          ),
                          right: _RecentPanel(
                            payments: recent.take(5).toList(),
                            nameOf: nameOf,
                            invoices: invoices,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _greeting(DateTime now) {
    final hour = now.hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.summary});

  final LedgerSummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = <Widget>[
          StatCard(
            label: 'Outstanding',
            value: formatPesewas(summary.outstanding),
            icon: Icons.account_balance_wallet_outlined,
            gradient: StatCard.primary,
            hint: '${summary.openCount} open ${summary.openCount == 1 ? 'invoice' : 'invoices'}',
            delay: const Duration(milliseconds: 60),
            onTap: () => context.go('/'),
          ),
          StatCard(
            label: 'Overdue',
            value: formatPesewas(summary.overdue),
            icon: Icons.warning_amber_rounded,
            gradient: StatCard.danger,
            accent: summary.overdue > 0
                ? AppTokens.of(context).danger
                : null,
            hint: summary.overdueCount == 0
                ? 'Nothing past its date'
                : '${summary.overdueCount} past ${summary.overdueCount == 1 ? 'its date' : 'their date'}',
            delay: const Duration(milliseconds: 120),
            onTap: () => context.go('/'),
          ),
          StatCard(
            label: 'Paid this month',
            value: formatPesewas(summary.paidThisMonth),
            icon: Icons.savings_outlined,
            gradient: StatCard.money,
            hint: '${formatPesewas(summary.invoicedThisMonth)} bought',
            delay: const Duration(milliseconds: 180),
            onTap: () => context.go('/payments'),
          ),
          StatCard(
            label: 'Suppliers',
            value: '${summary.supplierCount}',
            icon: Icons.local_shipping_outlined,
            gradient: StatCard.neutral,
            hint: '${summary.productCount} products · ${summary.invoiceCount} invoices',
            delay: const Duration(milliseconds: 240),
            onTap: () => context.go('/suppliers'),
          ),
        ];

        // Four across on a wide window, two on a narrow one, never one long
        // scroll of tiles.
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 520
                ? 2
                : 1;
        final gap = 12.0;
        final width =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }
}

/// Two panels side by side, stacked when the window is too narrow for both.
class _WideRow extends StatelessWidget {
  const _WideRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 860) {
          return Column(
            children: <Widget>[
              left,
              const SizedBox(height: 16),
              right,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(flex: 6, child: left),
            const SizedBox(width: 16),
            Expanded(flex: 5, child: right),
          ],
        );
      },
    );
  }
}

class _TrendPanel extends StatelessWidget {
  const _TrendPanel({
    required this.trend,
    required this.invoicedTotal,
    required this.paidTotal,
  });

  final List<MonthPoint> trend;
  final int invoicedTotal;
  final int paidTotal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    final peak = trend.fold<int>(0, (m, p) => p.invoiced > m ? p.invoiced : m);

    return FadeSlideIn(
      delay: const Duration(milliseconds: 300),
      child: SectionCard(
        title: 'Bought against paid',
        subtitle: 'The last six months',
        icon: Icons.stacked_line_chart_rounded,
        trailing: Wrap(
          spacing: 12,
          children: <Widget>[
            _LegendDot(color: scheme.primary, label: 'Bought'),
            _LegendDot(color: scheme.onSurface, label: 'Paid'),
          ],
        ),
        children: <Widget>[
          if (peak == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: Center(
                child: Text(
                  'No invoices in these six months yet.',
                  style: texts.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            )
          else
            TrendChart(
              labels: <String>[
                for (final point in trend)
                  DateFormat('MMM').format(point.month),
              ],
              primary: <double>[
                for (final point in trend)
                  peak == 0 ? 0 : point.invoiced / peak,
              ],
              primaryColor: scheme.primary,
              secondary: <double>[
                for (final point in trend)
                  peak == 0 ? 0 : point.paid / peak,
              ],
              secondaryColor: Aurora.emerald,
            ),
          const SizedBox(height: 6),
          LabelledDivider(
            label: 'All time',
            trailing: Text(
              '${formatPesewas(paidTotal)} of ${formatPesewas(invoicedTotal)}',
              style: texts.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _MiniFigure(
                  label: 'Bought',
                  value: formatPesewas(invoicedTotal),
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniFigure(
                  label: 'Paid',
                  value: formatPesewas(paidTotal),
                  color: Aurora.emerald,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniFigure(
                  label: 'Settled',
                  value: '${invoicedTotal == 0 ? 0 : ((paidTotal / invoicedTotal) * 100).round()}%',
                  color: Aurora.violet,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _MiniFigure extends StatelessWidget {
  const _MiniFigure({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: Frost.well(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: color,
                fontFeatures: AppTokens.tabularFigures,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttentionPanel extends StatelessWidget {
  const _AttentionPanel({
    required this.invoices,
    required this.now,
    required this.nameOf,
  });

  final List<SupplierInvoice> invoices;
  final DateTime now;
  final String Function(String) nameOf;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    return FadeSlideIn(
      delay: const Duration(milliseconds: 360),
      child: GlassPanel(
        radius: tokens.radiusLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PanelHeader(
              child: PanelTitle(
                title: 'Needs attention',
                icon: Icons.priority_high_rounded,
                trailing: invoices.isEmpty
                    ? null
                    : MiniPill(
                        '${invoices.length} late',
                        color: tokens.danger,
                        dense: true,
                      ),
              ),
            ),
            if (invoices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                child: Column(
                  children: <Widget>[
                    Icon(
                      Icons.verified_rounded,
                      size: 30,
                      color: tokens.success,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Nothing is past its date',
                      style: texts.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Every invoice is either settled or still within its terms.',
                      textAlign: TextAlign.center,
                      style: texts.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              )
            else
              for (final invoice in invoices)
                HoverRow(
                  onTap: () => context.go('/invoices/${invoice.id}'),
                  stripe: tokens.danger,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              nameOf(invoice.supplierId),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: texts.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${invoice.invoiceNumber} · due ${formatDate(invoice.dueDate)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: texts.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Money(
                            invoice.balancePesewas,
                            tone: MoneyTone.strong,
                            color: tokens.danger,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${daysLate(invoice, now)}d late',
                            style: texts.labelSmall?.copyWith(
                              color: tokens.danger,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _SupplierPanel extends StatelessWidget {
  const _SupplierPanel({required this.shares, required this.total});

  final List<SupplierShare> shares;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    return FadeSlideIn(
      delay: const Duration(milliseconds: 420),
      child: SectionCard(
        title: 'Where the money sits',
        subtitle: 'Outstanding by supplier',
        icon: Icons.account_tree_rounded,
        children: <Widget>[
          if (shares.isEmpty)
            Text(
              'No supplier has an outstanding balance.',
              style: texts.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            )
          else
            for (var i = 0; i < shares.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: 12),
              _ShareRow(
                share: shares[i],
                fraction: total == 0
                    ? 0
                    : shares[i].outstanding / total,
                accentIndex: i,
              ),
            ],
        ],
      ),
    );
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({
    required this.share,
    required this.fraction,
    required this.accentIndex,
  });

  final SupplierShare share;
  final double fraction;
  final int accentIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    return HoverRow(
      onTap: () => context.go('/suppliers'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              AvatarTile(
                name: share.supplier.name,
                accentIndex: accentIndex,
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  share.supplier.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: texts.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                share.outstanding == 0 ? 'Settled' : formatPesewas(share.outstanding),
                style: texts.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: share.outstanding == 0
                      ? scheme.onSurfaceVariant
                      : scheme.onSurface,
                  fontFeatures: AppTokens.tabularFigures,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: <Widget>[
              Expanded(
                child: MeterBar(
                  value: fraction,
                  color: Aurora.accent(accentIndex),
                  height: 5,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${share.invoiceCount} ${share.invoiceCount == 1 ? 'invoice' : 'invoices'}',
                style: texts.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentPanel extends StatelessWidget {
  const _RecentPanel({
    required this.payments,
    required this.nameOf,
    required this.invoices,
  });

  final List<Payment> payments;
  final String Function(String) nameOf;
  final List<SupplierInvoice> invoices;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    return FadeSlideIn(
      delay: const Duration(milliseconds: 480),
      child: GlassPanel(
        radius: AppTokens.of(context).radiusLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PanelHeader(
              child: PanelTitle(
                title: 'Recent payments',
                icon: Icons.history_rounded,
                trailing: TextButton(
                  onPressed: () => context.go('/payments'),
                  child: const Text('See all'),
                ),
              ),
            ),
            if (payments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                child: Column(
                  children: <Widget>[
                    Icon(
                      Icons.payments_outlined,
                      size: 28,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No payments recorded yet',
                      style: texts.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Payments you record appear here, newest first.',
                      textAlign: TextAlign.center,
                      style: texts.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              )
            else
              for (final payment in payments)
                HoverRow(
                  onTap: () => context.go('/payments'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Aurora.emerald.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          Icons.south_west_rounded,
                          size: 17,
                          color: Aurora.emerald,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              _supplierOf(payment),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: texts.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${formatDate(payment.date)} · ${payment.method}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: texts.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Money(payment.amountPesewas, tone: MoneyTone.strong),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  String _supplierOf(Payment payment) {
    for (final id in payment.invoiceIds) {
      for (final inv in invoices) {
        if (inv.id == id) return nameOf(inv.supplierId);
      }
    }
    return 'Opening balance';
  }
}
