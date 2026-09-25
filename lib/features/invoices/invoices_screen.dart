import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../data/receipt_storage.dart';
import '../../models/supplier.dart';
import '../../models/supplier_invoice.dart';
import '../../widgets/export_actions.dart';
import '../../widgets/aurora_background.dart';
import '../../widgets/more_menu_button.dart';
import '../../widgets/page_header.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/toast.dart';
import '../suppliers/suppliers_controller.dart';
import 'invoices_controller.dart';

enum _FilterStatus { all, outstanding, overdue, paid }

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  String? _filterSupplierId;
  _FilterStatus _filterStatus = _FilterStatus.all;
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
      switch (_filterStatus) {
        case _FilterStatus.all:
          break;
        case _FilterStatus.outstanding:
          if (i.statusAt(now) == InvoiceStatus.paid) return false;
          break;
        case _FilterStatus.overdue:
          if (i.statusAt(now) != InvoiceStatus.overdue) return false;
          break;
        case _FilterStatus.paid:
          if (i.statusAt(now) != InvoiceStatus.paid) return false;
          break;
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

    final allSelected =
        sorted.isNotEmpty && sorted.every((s) => _selected.contains(s.id));

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
            child: PageHeader(
              title: 'Invoices',
              subtitle:
                  '${invoices.length} ${invoices.length == 1 ? 'invoice' : 'invoices'} · ${DateFormat('EEEE, d MMMM yyyy').format(now)}',
              icon: Icons.receipt_long,
              accentIndex: 0,
              actions: <Widget>[
                MoreMenuButton(),
                FilledButton.icon(
                  onPressed: () => context.go('/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('New Invoice'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
            child: FadeSlideIn(
              delay: const Duration(milliseconds: 70),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.55),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search invoices…',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      flex: 1,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant
                                  .withValues(alpha: 0.7),
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          child: DropdownButton<String?>(
                            value: _filterSupplierId,
                            hint: const Text('All suppliers'),
                            underline: const SizedBox.shrink(),
                            borderRadius: BorderRadius.circular(14),
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
                            onChanged: (v) =>
                                setState(() => _filterSupplierId = v),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      flex: 1,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          key: const Key('status-filter'),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant
                                  .withValues(alpha: 0.7),
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          child: DropdownButton<_FilterStatus>(
                            value: _filterStatus,
                            underline: const SizedBox.shrink(),
                            borderRadius: BorderRadius.circular(14),
                            items: const [
                              DropdownMenuItem<_FilterStatus>(
                                value: _FilterStatus.all,
                                child: Text('All statuses'),
                              ),
                              DropdownMenuItem<_FilterStatus>(
                                value: _FilterStatus.outstanding,
                                child: Text('Outstanding'),
                              ),
                              DropdownMenuItem<_FilterStatus>(
                                value: _FilterStatus.overdue,
                                child: Text('Overdue'),
                              ),
                              DropdownMenuItem<_FilterStatus>(
                                value: _FilterStatus.paid,
                                child: Text('Paid'),
                              ),
                            ],
                            onChanged: (v) => setState(
                                () => _filterStatus = v ?? _FilterStatus.all),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                  ],
                ),
              ),
            ),
          ),
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
                  : () =>
                      exportCsv(context, ref, invoices: true, invoiceIds: _selected),
              onExportZip: _selected.isEmpty
                  ? null
                  : () => exportZip(context, ref, invoiceIds: _selected),
              onDelete: _selected.isEmpty
                  ? null
                  : () => _confirmBulkDelete(context, sorted),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
            child: Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Total outstanding',
                    value: formatPesewas(totalOwing),
                    icon: Icons.account_balance_wallet_outlined,
                    gradient: StatCard.primary,
                    delay: const Duration(milliseconds: 120),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Overdue',
                    value: formatPesewas(overdue),
                    icon: Icons.warning_amber_rounded,
                    gradient: StatCard.danger,
                    delay: const Duration(milliseconds: 190),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Unpaid',
                    value: '$openCount',
                    icon: Icons.pending_actions_outlined,
                    gradient: StatCard.neutral,
                    delay: const Duration(milliseconds: 260),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Invoices',
                    value: '${allVisible.length}',
                    icon: Icons.receipt_long_outlined,
                    gradient: StatCard.primary,
                    delay: const Duration(milliseconds: 330),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: sorted.isEmpty
                ? _EmptyInvoices(onAdd: () => context.go('/new'))
                : _InvoiceTable(
                    invoices: sorted,
                    supplierNames: {
                      for (final s in suppliers) s.id: s.name,
                    },
                    now: now,
                    selectionMode: _selectionMode,
                    selected: _selected,
                    onToggle: (id) => setState(() {
                      if (!_selected.add(id)) _selected.remove(id);
                    }),
                    onOpen: (id) {
                      if (_selectionMode) {
                        setState(() {
                          if (!_selected.add(id)) _selected.remove(id);
                        });
                      } else {
                        context.go('/invoices/$id');
                      }
                    },
                    onEnterSelection: (id) => setState(() {
                      _selectionMode = true;
                      _selected.add(id);
                    }),
                  ),
          ),
        ],
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
    if (ok != true || !mounted || !context.mounted) return;

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

class _InvoiceTable extends StatelessWidget {
  const _InvoiceTable({
    required this.invoices,
    required this.supplierNames,
    required this.now,
    required this.selectionMode,
    required this.selected,
    required this.onToggle,
    required this.onOpen,
    required this.onEnterSelection,
  });

  final List<SupplierInvoice> invoices;
  final Map<String, String> supplierNames;
  final DateTime now;
  final bool selectionMode;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onEnterSelection;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.72),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: scheme.primary.withValues(alpha: isDark ? 0.18 : 0.10),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          children: [
            _HeaderRow(selectionMode: selectionMode),
            Expanded(
              child: ListView.builder(
                itemCount: invoices.length,
                itemBuilder: (context, index) {
                  final inv = invoices[index];
                  return _InvoiceRow(
                    invoice: inv,
                    supplierName:
                        supplierNames[inv.supplierId] ?? 'Unknown',
                    now: now,
                    selectionMode: selectionMode,
                    selected: selected.contains(inv.id),
                    onTap: () => onOpen(inv.id),
                    onToggle: () => onToggle(inv.id),
                    onSecondaryTap: () {
                      if (!selectionMode) onEnterSelection(inv.id);
                    },
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

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.selectionMode});

  final bool selectionMode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        );
    Widget cell(String label, {double flex = 1, TextAlign align = TextAlign.left}) {
      return Expanded(
        flex: flex ~/ 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: Text(
            label,
            textAlign: align,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            scheme.primary.withValues(alpha: 0.10),
            scheme.primary.withValues(alpha: 0.04),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          if (selectionMode) const SizedBox(width: 18),
          cell('Supplier', flex: 22),
          cell('Invoice No', flex: 13),
          cell('Due', flex: 10),
          cell('Total (GH₵)', flex: 10, align: TextAlign.right),
          cell('Paid (GH₵)', flex: 10, align: TextAlign.right),
          cell('Balance (GH₵)', flex: 10, align: TextAlign.right),
          cell('Status', flex: 12),
        ],
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({
    required this.invoice,
    required this.supplierName,
    required this.now,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onToggle,
    required this.onSecondaryTap,
  });

  final SupplierInvoice invoice;
  final String supplierName;
  final DateTime now;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = invoice.statusAt(now);
    final texts = Theme.of(context).textTheme;

    Widget cell(String text, {double flex = 1, TextAlign align = TextAlign.left, TextStyle? style}) {
      return Expanded(
        flex: flex ~/ 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Text(
            text,
            textAlign: align,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.45)
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onSecondaryTap: onSecondaryTap,
          hoverColor: scheme.primary.withValues(alpha: 0.05),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // A colour stripe down the edge, so the state of an invoice can
              // be read without reading the pill.
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: SizedBox(
                  width: 3,
                  child: ColoredBox(
                    color: StatusBadge.colorOf(status).withValues(alpha: 0.85),
                  ),
                ),
              ),
              Row(
                children: [
                  if (selectionMode)
                    Padding(
                      padding: const EdgeInsets.only(left: 14, right: 2),
                      child: Checkbox(
                        value: selected,
                        onChanged: (_) => onToggle(),
                      ),
                    ),
                  cell(supplierName, flex: 22,
                      style: texts.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  cell(invoice.invoiceNumber, flex: 13,
                      style: texts.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  cell(formatDate(invoice.dueDate), flex: 10),
                  cell(
                    formatPesewas(invoice.totalPesewas),
                    flex: 10,
                    align: TextAlign.right,
                    style: texts.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  cell(formatPesewas(invoice.amountPaidPesewas), flex: 10,
                      align: TextAlign.right),
                  cell(
                    formatPesewas(invoice.balancePesewas),
                    flex: 10,
                    align: TextAlign.right,
                    style: texts.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: invoice.owesMoney ? scheme.error : scheme.onSurface,
                    ),
                  ),
                  Expanded(
                    flex: 12,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: StatusBadge(status: status),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: FadeSlideIn(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: <Color>[
                scheme.primary.withValues(alpha: 0.16),
                scheme.primary.withValues(alpha: 0.08),
              ],
            ),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.28)),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Exit selection',
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
              Expanded(
                child: Text(
                  count == 0 ? 'Select invoices' : '$count selected',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Select all',
                onPressed: onSelectAll,
                icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
              ),
              IconButton(
                tooltip: 'Export CSV',
                onPressed: onExportCsv,
                icon: const Icon(Icons.table_chart_outlined),
              ),
              IconButton(
                tooltip: 'Export backup',
                onPressed: onExportZip,
                icon: const Icon(Icons.archive_outlined),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
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
    return EmptyState(
      icon: Icons.receipt_long_outlined,
      title: 'No invoices yet',
      message: 'Record invoices you buy medicines on from your suppliers.',
      action: FilledButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add),
        label: const Text('Add invoice'),
      ),
    );
  }
}