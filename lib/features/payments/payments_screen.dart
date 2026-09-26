import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/payment.dart';
import '../../widgets/aurora_background.dart';
import '../../widgets/export_actions.dart';
import '../../widgets/page_header.dart';
import '../../widgets/stat_card.dart';
import '../invoices/invoices_controller.dart';
import '../suppliers/suppliers_controller.dart';
import 'payments_controller.dart';

/// Every payment made, newest first, with the running totals worked out across
/// all the invoices rather than one row at a time.
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
    final scheme = Theme.of(context).colorScheme;

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
    final visible = [
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

    final thisMonth = payments
        .where((p) => p.date.year == now.year && p.date.month == now.month)
        .fold(0, (sum, p) => sum + p.amountPesewas);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
            child: PageHeader(
              title: 'Payments',
              subtitle: payments.isEmpty
                  ? 'Every payment you make, and what it settled'
                  : '${payments.length} '
                      '${payments.length == 1 ? 'payment' : 'payments'} recorded',
              icon: Icons.payments_outlined,
              accentIndex: 4,
              actions: [
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
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
            child: FadeSlideIn(
              delay: const Duration(milliseconds: 60),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 250,
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search payments…',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.7),
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          key: const Key('payments-supplier-filter'),
                          isExpanded: true,
                          value: _supplierFilter,
                          hint: const Text('All suppliers'),
                          borderRadius: BorderRadius.circular(14),
                          items: [
                            const DropdownMenuItem<String>(
                              value: 'all',
                              child: Text('All suppliers'),
                            ),
                            for (final s in suppliers)
                              DropdownMenuItem<String>(
                                value: s.id,
                                child: Text(
                                  s.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) =>
                              setState(() => _supplierFilter = v ?? 'all'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
            child: FadeSlideIn(
              delay: const Duration(milliseconds: 120),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  StatCard(
                    label: 'Total paid',
                    value: formatPesewas(paidTotal),
                    icon: Icons.savings_outlined,
                    gradient: const <Color>[Aurora.emerald, Aurora.teal],
                  ),
                  StatCard(
                    label: 'Still owed',
                    value: formatPesewas(outstandingTotal),
                    icon: Icons.account_balance_wallet_outlined,
                    gradient: const <Color>[Aurora.indigo, Aurora.sky],
                  ),
                  StatCard(
                    label: 'Overdue',
                    value: formatPesewas(overdueTotal),
                    icon: Icons.warning_amber_rounded,
                    gradient: const <Color>[Aurora.rose, Aurora.amber],
                  ),
                  StatCard(
                    label: 'Paid this month',
                    value: formatPesewas(thisMonth),
                    icon: Icons.event_available_outlined,
                    gradient: const <Color>[Aurora.violet, Aurora.pink],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: visible.isEmpty
                ? _EmptyPayments(hasAny: payments.isNotEmpty)
                : _PaymentsTable(
                    payments: visible,
                    supplierNameFor: supplierOfInvoice,
                    invoiceNumberFor: invoiceNumberOf,
                    onRemove: (p) => _confirmRemove(context, p),
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
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          FilledButton(
            child: const Text('Delete'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (ok ?? false) await notifier.remove(payment.id);
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _PaymentsTable extends StatelessWidget {
  const _PaymentsTable({
    required this.payments,
    required this.supplierNameFor,
    required this.invoiceNumberFor,
    required this.onRemove,
  });

  final List<Payment> payments;
  final String Function(String invoiceId) supplierNameFor;
  final String Function(String invoiceId) invoiceNumberFor;
  final ValueChanged<Payment> onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerStyle = texts.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.8,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.72),
        border:
            Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Aurora.violet.withValues(alpha: isDark ? 0.18 : 0.10),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    scheme.primary.withValues(alpha: 0.10),
                    scheme.primary.withValues(alpha: 0.04),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Expanded(flex: 18, child: Text('Date', style: headerStyle)),
                    Expanded(
                      flex: 26,
                      child: Text('Supplier', style: headerStyle),
                    ),
                    Expanded(
                      flex: 24,
                      child: Text('Settled', style: headerStyle),
                    ),
                    Expanded(
                      flex: 14,
                      child: Text('Method', style: headerStyle),
                    ),
                    Expanded(
                      flex: 18,
                      child: Text(
                        'Amount',
                        textAlign: TextAlign.right,
                        style: headerStyle,
                      ),
                    ),
                    const SizedBox(width: 29),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: payments.length,
                itemBuilder: (context, index) {
                  final p = payments[index];
                  return _PaymentRow(
                    payment: p,
                    supplierName: p.invoiceIds.isEmpty
                        ? '—'
                        : supplierNameFor(p.invoiceIds.first),
                    numbers: [
                      for (final id in p.invoiceIds) invoiceNumberFor(id),
                    ],
                    accentIndex: index,
                    onTap: () => onRemove(p),
                  );
                },
              ),
            ),
          ],
        ),
      ),
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
    final colors = Aurora.pair(accentIndex + 4);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Expanded(
                flex: 18,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 30,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: colors,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formatDate(payment.date),
                            style: texts.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
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
                  ],
                ),
              ),
              Expanded(
                flex: 26,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      supplierName,
                      style: texts.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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
              Expanded(
                flex: 24,
                child: Text(
                  numbers.isEmpty ? '—' : numbers.join(', '),
                  style: texts.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 14,
                child: Text(
                  payment.method,
                  style: texts.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 18,
                child: Text(
                  formatPesewas(payment.amountPesewas),
                  textAlign: TextAlign.right,
                  style: texts.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.undo, size: 17, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
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
