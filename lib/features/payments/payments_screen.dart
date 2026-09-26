import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/payment.dart';
import '../../widgets/export_actions.dart';
import '../../widgets/page_header.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/ui_kit.dart';
import '../invoices/invoices_controller.dart';
import '../suppliers/suppliers_controller.dart';
import 'payments_controller.dart';

/// The room the undo mark takes at the end of a row.
const double _undoGutter = 40;

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  String _query = '';
  String _supplierFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final payments = ref.watch(paymentsProvider);
    final invoices = ref.watch(invoicesProvider);
    final suppliers = ref.watch(suppliersProvider);

    String supplierNameOf(String supplierId) {
      for (final s in suppliers) {
        if (s.id == supplierId) return s.name;
      }
      return 'Unknown supplier';
    }

    String invoiceNumberOf(String invoiceId) {
      for (final i in invoices) {
        if (i.id == invoiceId) return i.invoiceNumber;
      }
      return '';
    }

    String supplierOfInvoice(String invoiceId) {
      for (final i in invoices) {
        if (i.id == invoiceId) return supplierNameOf(i.supplierId);
      }
      return 'Unknown supplier';
    }

    // A payment belongs to whoever the invoices it settles belong to, which is
    // how the supplier filter and the search both find it.
    bool matchesSupplier(Payment p) {
      if (_supplierFilter == 'all') return true;
      for (final id in p.invoiceIds) {
        for (final i in invoices) {
          if (i.id == id && i.supplierId == _supplierFilter) return true;
        }
      }
      return false;
    }

    final q = _query.trim().toLowerCase();
    final visible = <Payment>[
      for (final p in payments)
        if (matchesSupplier(p))
          if (q.isEmpty ||
              p.method.toLowerCase().contains(q) ||
              p.reference.toLowerCase().contains(q) ||
              p.notes.toLowerCase().contains(q) ||
              p.invoiceIds.any((id) {
                final number = invoiceNumberOf(id).toLowerCase();
                if (number.contains(q)) return true;
                return supplierOfInvoice(id).toLowerCase().contains(q);
              }))
            p,
    ];

    var paidTotal = 0;
    var outstandingTotal = 0;
    var overdueTotal = 0;
    final now = DateTime.now();
    for (final inv in invoices) {
      paidTotal += inv.amountPaidPesewas;
      final balance = inv.balancePesewas;
      if (balance <= 0) continue;
      outstandingTotal += balance;
      if (inv.dueDate.isBefore(now) && !_sameDay(inv.dueDate, now)) {
        overdueTotal += balance;
      }
    }

    var thisMonthCount = 0;
    var thisMonth = 0;
    for (final p in payments) {
      if (p.date.year != now.year || p.date.month != now.month) continue;
      thisMonth += p.amountPesewas;
      thisMonthCount++;
    }

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: Insets.page,
            child: PageHeader(
              title: 'Payments',
              subtitle: payments.isEmpty
                  ? 'Every payment you make, and what it settled'
                  : '${payments.length} '
                      '${payments.length == 1 ? 'payment' : 'payments'} recorded',
              icon: Icons.payments_outlined,
              accentIndex: 4,
              meta: <Widget>[
                MiniPill(
                  '$thisMonthCount this month',
                  icon: Icons.event_available_outlined,
                  dense: true,
                ),
              ],
              actions: <Widget>[
                OutlinedButton.icon(
                  onPressed: payments.isEmpty
                      ? null
                      : () => exportPaymentsCsv(
                            context,
                            ref,
                            payments: payments,
                          ),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Export'),
                ),
                FilledButton.icon(
                  key: const Key('new-payment'),
                  onPressed: () => context.go('/payments/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('Record payment'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Insets.xxl, Insets.md, Insets.xxl, 0),
            child: FilterBar(
              delay: const Duration(milliseconds: 70),
              children: <Widget>[
                SearchField(
                  hint: 'Search payments…',
                  onChanged: (v) => setState(() => _query = v),
                ),
                FilterSelect<String>(
                  buttonKey: const Key('payments-supplier-filter'),
                  value: _supplierFilter,
                  hint: 'All suppliers',
                  items: <DropdownMenuItem<String>>[
                    const DropdownMenuItem<String>(
                      value: 'all',
                      child: Text('All suppliers'),
                    ),
                    for (final s in suppliers)
                      DropdownMenuItem<String>(
                        value: s.id,
                        child: Text(s.name),
                      ),
                  ],
                  onChanged: (v) => setState(
                    () => _supplierFilter = v ?? 'all',
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Insets.xxl, Insets.md, Insets.xxl, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: StatCard(
                    label: 'Total paid',
                    value: formatPesewas(paidTotal),
                    icon: Icons.savings_outlined,
                    gradient: StatCard.money,
                    delay: const Duration(milliseconds: 120),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Still owed',
                    value: formatPesewas(outstandingTotal),
                    icon: Icons.account_balance_wallet_outlined,
                    gradient: StatCard.primary,
                    delay: const Duration(milliseconds: 190),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Overdue',
                    value: formatPesewas(overdueTotal),
                    icon: Icons.warning_amber_rounded,
                    gradient: StatCard.danger,
                    delay: const Duration(milliseconds: 260),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Paid this month',
                    value: formatPesewas(thisMonth),
                    icon: Icons.event_available_outlined,
                    gradient: StatCard.neutral,
                    delay: const Duration(milliseconds: 330),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.md),
          Expanded(
            child: visible.isEmpty
                ? _EmptyPayments(hasAny: payments.isNotEmpty)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.xxl,
                      0,
                      Insets.xxl,
                      Insets.xxl,
                    ),
                    child: TableScaffold(
                      header: const _PaymentHeadings(),
                      footer: _PaymentsFooter(
                        shown: visible.length,
                        total: payments.length,
                      ),
                      body: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final p = visible[index];
                          return _PaymentRow(
                            payment: p,
                            supplierName: p.invoiceIds.isEmpty
                                ? '—'
                                : supplierOfInvoice(p.invoiceIds.first),
                            numbers: <String>[
                              for (final id in p.invoiceIds) invoiceNumberOf(id),
                            ],
                            accentIndex: index,
                            onTap: () => _confirmRemove(context, p),
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, Payment payment) async {
    final notifier = ref.read(paymentsProvider.notifier);
    final count = payment.allocations.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this payment?'),
        content: Text(
          'The ${formatPesewas(payment.amountPesewas)} will go back onto '
          '$count ${count == 1 ? 'invoice' : 'invoices'} as outstanding.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok ?? false) await notifier.remove(payment.id);
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _PaymentHeadings extends StatelessWidget {
  const _PaymentHeadings();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: <Widget>[
        ColumnHeading('Date', flex: 16),
        ColumnHeading('Supplier', flex: 26),
        ColumnHeading('Settled', flex: 24),
        ColumnHeading('Method', flex: 14),
        ColumnHeading('Amount', flex: 16, trailing: true),
        SizedBox(width: _undoGutter),
      ],
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.payment,
    required this.supplierName,
    required this.numbers,
    required this.accentIndex,
    required this.onTap,
  });

  final Payment payment;
  final String supplierName;
  final List<String> numbers;
  final int accentIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;

    return HoverRow(
      onTap: onTap,
      onSecondaryTap: onTap,
      stripe: Aurora.accent(accentIndex + 4),
      child: Row(
        children: <Widget>[
          TableCellBox(
            flex: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  formatDate(payment.date),
                  style: texts.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (payment.isLegacy)
                  Text(
                    'Opening balance',
                    style: texts.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          TableCellBox(
            flex: 26,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  supplierName,
                  style: texts.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (payment.reference.isNotEmpty)
                  Text(
                    payment.reference,
                    style: texts.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          TableCellBox(
            flex: 24,
            child: Text(
              numbers.isEmpty ? '—' : numbers.join(', '),
              style: texts.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TableCellBox(
            flex: 14,
            child: Text(
              payment.method,
              style: texts.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TableCellBox(
            flex: 16,
            align: CrossAxisAlignment.end,
            child: Money(payment.amountPesewas, tone: MoneyTone.strong),
          ),
          SizedBox(
            width: _undoGutter,
            child: Icon(
              Icons.undo,
              size: 17,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentsFooter extends StatelessWidget {
  const _PaymentsFooter({required this.shown, required this.total});

  final int shown;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Icon(
          Icons.receipt_long_outlined,
          size: 14,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            shown == total
                ? '$shown of $total shown'
                : '$shown of $total shown, filtered',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}

class _EmptyPayments extends StatelessWidget {
  const _EmptyPayments({required this.hasAny});

  final bool hasAny;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.payments_outlined,
      title: hasAny ? 'No payments match' : 'No payments yet',
      message: hasAny
          ? 'Try a different search, or clear the supplier filter.'
          : 'When you pay a supplier, record it here. One payment can settle '
              'several invoices at once, and the balances add themselves up.',
      accentIndex: 4,
      action: hasAny
          ? null
          : FilledButton.icon(
              onPressed: () => context.go('/payments/new'),
              icon: const Icon(Icons.add),
              label: const Text('Record payment'),
            ),
    );
  }
}
