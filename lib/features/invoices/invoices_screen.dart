import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../models/supplier.dart';
import '../../models/supplier_invoice.dart';
import '../../widgets/more_menu_button.dart';
import 'invoices_controller.dart';
import '../suppliers/suppliers_controller.dart';

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  String? _filterSupplierId;

  @override
  Widget build(BuildContext context) {
    final invoices = ref.watch(invoicesProvider);
    final suppliers = ref.watch(suppliersProvider);

    String nameOf(String supplierId) {
      for (final s in suppliers) {
        if (s.id == supplierId) return s.name;
      }
      return 'Unknown';
    }

    final now = DateTime.now();
    final visible = _filterSupplierId == null
        ? invoices
        : invoices.where((i) => i.supplierId == _filterSupplierId).toList();

    var totalOwing = 0;
    var overdue = 0;
    var openCount = 0;
    for (final inv in visible) {
      if (inv.balancePesewas <= 0) continue;
      openCount++;
      totalOwing += inv.balancePesewas;
      if (inv.statusAt(now) == InvoiceStatus.overdue) {
        overdue += inv.balancePesewas;
      }
    }

    final sorted = [...visible]..sort((a, b) {
      final ra = _rank(a, now);
      final rb = _rank(b, now);
      if (ra != rb) return ra.compareTo(rb);
      return a.dueDate.compareTo(b.dueDate);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Tracker'),
        actions: const [MoreMenuButton(), SizedBox(width: 8)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                _SummaryCard(
                  label: 'Total owing',
                  value: formatPesewas(totalOwing),
                  highlighted: totalOwing > 0,
                ),
                const SizedBox(width: 8),
                _SummaryCard(
                  label: 'Overdue',
                  value: formatPesewas(overdue),
                  highlighted: overdue > 0,
                ),
                const SizedBox(width: 8),
                _SummaryCard(
                  label: 'Unpaid',
                  value: '$openCount',
                  highlighted: openCount > 0,
                ),
                const Spacer(),
                DropdownButton<String?>(
                  value: _filterSupplierId,
                  hint: const Text('All suppliers'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All suppliers'),
                    ),
                    for (final Supplier s in suppliers)
                      DropdownMenuItem<String?>(
                        value: s.id,
                        child: Text(s.name),
                      ),
                  ],
                  onChanged: (v) => setState(() => _filterSupplierId = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: sorted.isEmpty
                ? _EmptyInvoices(
                    onAdd: () => context.go('/new'),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                    child: DataTable(
                      headingRowHeight: 44,
                      dataRowMinHeight: 44,
                      dataRowMaxHeight: 56,
                      columns: const [
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Supplier')),
                        DataColumn(label: Text('Invoice No')),
                        DataColumn(label: Text('Description')),
                        DataColumn(label: Text('Total'), numeric: true),
                        DataColumn(label: Text('Paid'), numeric: true),
                        DataColumn(label: Text('Balance'), numeric: true),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: [
                        for (final inv in sorted)
                          DataRow(
                            color: WidgetStatePropertyAll(
                              _rowColor(context, inv, now),
                            ),
                            onSelectChanged: (_) =>
                                context.go('/invoices/${inv.id}'),
                            cells: [
                              DataCell(Text(formatDate(inv.invoiceDate))),
                              DataCell(
                                Text(nameOf(inv.supplierId),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              DataCell(Text(inv.invoiceNumber)),
                              DataCell(
                                Text(inv.description,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              DataCell(
                                  Text(formatPesewas(inv.totalPesewas))),
                              DataCell(
                                  Text(formatPesewas(inv.amountPaidPesewas))),
                              DataCell(
                                  Text(formatPesewas(inv.balancePesewas))),
                              DataCell(Text(inv.statusAt(now).label)),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/new'),
        icon: const Icon(Icons.add),
        label: const Text('Invoice'),
      ),
    );
  }

  int _rank(SupplierInvoice inv, DateTime now) {
    final status = inv.statusAt(now);
    switch (status) {
      case InvoiceStatus.overdue:
        return 0;
      case InvoiceStatus.open:
        return 1;
      case InvoiceStatus.partiallyPaid:
        return 2;
      case InvoiceStatus.paid:
        return 3;
    }
  }

  Color? _rowColor(BuildContext context, SupplierInvoice inv, DateTime now) {
    if (!inv.owesMoney) return null;
    if (inv.statusAt(now) == InvoiceStatus.overdue) {
      return Theme.of(context).colorScheme.errorContainer.withOpacity(0.5);
    }
    return Colors.amber.withOpacity(0.18);
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.highlighted,
  });

  final String label;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: highlighted ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: highlighted
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: highlighted ? scheme.onPrimaryContainer : scheme.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmptyInvoices extends StatelessWidget {
  const _EmptyInvoices({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text('No invoices yet', style: texts.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Record invoices you buy medicines on from your suppliers.',
              style: texts.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add invoice'),
            ),
          ],
        ),
      ),
    );
  }
}