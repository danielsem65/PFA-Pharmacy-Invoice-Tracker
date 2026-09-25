import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../data/receipt_storage.dart';
import '../../models/supplier.dart';
import '../../models/supplier_invoice.dart';
import '../../widgets/export_actions.dart';
import '../../widgets/more_menu_button.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/status_badge.dart';
import '../suppliers/suppliers_controller.dart';
import 'invoices_controller.dart';

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  String? _filterSupplierId;
  String _query = '';
  final Set<String> _selected = {};
  bool _selectionMode = false;

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
    final q = _query.trim().toLowerCase();
    final allVisible = invoices.where((i) {
      if (_filterSupplierId != null && i.supplierId != _filterSupplierId) {
        return false;
      }
      if (q.isNotEmpty) {
        final hay = '${nameOf(i.supplierId)} ${i.invoiceNumber} '
            '${i.description} ${i.reference}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    var totalOwing = 0;
    var overdue = 0;
    var openCount = 0;
    for (final inv in allVisible) {
      if (inv.balancePesewas <= 0) continue;
      openCount++;
      totalOwing += inv.balancePesewas;
      if (inv.statusAt(now) == InvoiceStatus.overdue) {
        overdue += inv.balancePesewas;
      }
    }

    final sorted = [...allVisible]..sort((a, b) {
      final ra = _rank(a, now);
      final rb = _rank(b, now);
      if (ra != rb) return ra.compareTo(rb);
      return a.dueDate.compareTo(b.dueDate);
    });

    final allSelected = sorted.isNotEmpty && sorted.every((s) => _selected.contains(s.id));

    return Scaffold(
      body: Column(
        children: [
          if (_selectionMode)
            _SelectionBar(
              count: _selected.length,
              onClose: () => setState(() {
                _selectionMode = false;
                _selected.clear();
              }),
              onSelectAll: () => setState(() {
                if (allSelected) {
                  _selected.removeAll(sorted.map((e) => e.id));
                } else {
                  _selected.addAll(sorted.map((e) => e.id));
                }
              }),
              allSelected: allSelected,
              onExportCsv: _selected.isEmpty
                  ? null
                  : () => exportCsv(context, ref, invoices: true, invoiceIds: _selected),
              onExportZip: _selected.isEmpty
                  ? null
                  : () => exportZip(context, ref, invoiceIds: _selected),
              onDelete: _selected.isEmpty
                  ? null
                  : () => _confirmBulkDelete(context, sorted),
            )
          else
            _Header(
              outstanding: totalOwing,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                _SummaryPill(
                  label: 'INVOICES',
                  value: '${allVisible.length}',
                  icon: Icons.receipt_long_outlined,
                  gradient: StatCard.primary,
                ),
                const SizedBox(width: 10),
                _SummaryPill(
                  label: 'OVERDUE',
                  value: formatPesewas(overdue),
                  icon: Icons.warning_amber_rounded,
                  gradient: StatCard.danger,
                ),
                const SizedBox(width: 10),
                _SummaryPill(
                  label: 'UNPAID',
                  value: '$openCount',
                  icon: Icons.pending_actions_outlined,
                  gradient: StatCard.neutral,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search invoices…',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  tooltip: 'Select invoices',
                  onPressed: sorted.isEmpty
                      ? null
                      : () => setState(() {
                            _selectionMode = true;
                            if (_selected.isEmpty) {
                              _selected.add(sorted.first.id);
                            }
                          }),
                  icon: const Icon(Icons.checklist_rounded),
                ),
                const SizedBox(width: 6),
                DropdownButton<String?>(
                  value: _filterSupplierId,
                  hint: const Text('All suppliers'),
                  borderRadius: BorderRadius.circular(14),
                  underline: const SizedBox.shrink(),
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
                ? _EmptyInvoices(onAdd: () => context.go('/new'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                    itemCount: sorted.length,
                    itemBuilder: (context, index) {
                      final inv = sorted[index];
                      return _InvoiceCard(
                        invoice: inv,
                        supplierName: nameOf(inv.supplierId),
                        selectionMode: _selectionMode,
                        selected: _selected.contains(inv.id),
                        onTap: () {
                          if (_selectionMode) {
                            setState(() {
                              if (!_selected.add(inv.id)) _selected.remove(inv.id);
                            });
                          } else {
                            context.go('/invoices/${inv.id}');
                          }
                        },
                        onLongPress: () {
                          setState(() {
                            _selectionMode = true;
                            _selected.add(inv.id);
                          });
                        },
                      );
                    },
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

  Future<void> _confirmBulkDelete(
    BuildContext context,
    List<SupplierInvoice> visible,
  ) async {
    final selectedIds = Set.of(_selected);
    final count = selectedIds.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(count == 1 ? 'Delete invoice?' : 'Delete $count invoices?'),
        content: Text(
          count == 1
              ? 'This invoice and its attachments will be removed. '
                  'This cannot be undone.'
              : 'These invoices and their attachments will be removed. '
                  'This cannot be undone.',
        ),
        actions: [
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
    if (ok != true || !mounted) return;

    final removed = visible.where((i) => selectedIds.contains(i.id)).toList();
    final storage = ref.read(receiptStorageProvider);
    for (final inv in removed) {
      for (final name in inv.receipts) {
        await storage.deleteReceiptFile(name);
      }
    }
    await ref.read(invoicesProvider.notifier).removeMany(selectedIds);
    if (!mounted || !context.mounted) return;
    setState(() {
      _selected.clear();
      _selectionMode = _selected.isNotEmpty;
    });
    toast(context, count == 1 ? 'Invoice deleted.' : '$count invoices deleted.');
  }

  int _rank(SupplierInvoice inv, DateTime now) {
    switch (inv.statusAt(now)) {
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
}

class _Header extends StatelessWidget {
  const _Header({required this.outstanding});

  final int outstanding;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateLabel = DateFormat('EEEE, d MMMM yyyy').format(now);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B3B52), Color(0xFF0E7490)],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invoice Tracker',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                    ),
                  ],
                ),
              ),
              MoreMenuButton(color: Colors.white),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'TOTAL OUTSTANDING',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            formatPesewas(outstanding),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
  });

  final String label;
  final String value;
  final IconData icon;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.28),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.95)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
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

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.invoice,
    required this.supplierName,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final SupplierInvoice invoice;
  final String supplierName;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final status = invoice.statusAt(now);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.55)
            : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? scheme.primary.withValues(alpha: 0.6)
                    : scheme.outlineVariant.withValues(alpha: 0.5),
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                if (selectionMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Checkbox(
                      value: selected,
                      onChanged: (_) => onTap(),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  supplierName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Wrap(
                                  spacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      invoice.invoiceNumber,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    Text(
                                      '· Due ${formatDate(invoice.dueDate)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge(status: status),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _MoneyStat(
                            label: 'TOTAL',
                            value: formatPesewas(invoice.totalPesewas),
                          ),
                          Container(
                            width: 1,
                            height: 28,
                            color: scheme.outlineVariant.withValues(alpha: 0.6),
                          ),
                          _MoneyStat(
                            label: 'PAID',
                            value: formatPesewas(invoice.amountPaidPesewas),
                          ),
                          Container(
                            width: 1,
                            height: 28,
                            color: scheme.outlineVariant.withValues(alpha: 0.6),
                          ),
                          _MoneyStat(
                            label: 'BALANCE',
                            value: formatPesewas(invoice.balancePesewas),
                            emphasized: invoice.owesMoney,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoneyStat extends StatelessWidget {
  const _MoneyStat({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: emphasized
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.onClose,
    required this.onSelectAll,
    required this.allSelected,
    required this.onExportCsv,
    required this.onExportZip,
    required this.onDelete,
  });

  final int count;
  final VoidCallback onClose;
  final VoidCallback onSelectAll;
  final bool allSelected;
  final VoidCallback? onExportCsv;
  final VoidCallback? onExportZip;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Exit selection',
                onPressed: onClose,
                icon: Icon(Icons.close, color: scheme.onPrimaryContainer),
              ),
              Expanded(
                child: Text(
                  count == 0 ? 'Select invoices' : '$count selected',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onPrimaryContainer,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Select all',
                onPressed: onSelectAll,
                icon: Icon(
                  allSelected
                      ? Icons.deselect
                      : Icons.select_all,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              IconButton(
                tooltip: 'Export CSV',
                onPressed: onExportCsv,
                icon: Icon(Icons.table_chart_outlined, color: scheme.onPrimaryContainer),
              ),
              IconButton(
                tooltip: 'Export backup',
                onPressed: onExportZip,
                icon: Icon(Icons.archive_outlined, color: scheme.onPrimaryContainer),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
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
