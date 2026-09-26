import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/design.dart';
import '../../core/format.dart';
import '../../data/receipt_storage.dart';
import '../../models/supplier.dart';
import '../../models/supplier_invoice.dart';
import '../../widgets/aurora_background.dart';
import '../../widgets/export_actions.dart';
import '../../widgets/more_menu_button.dart';
import '../../widgets/page_header.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/toast.dart';
import '../../widgets/ui_kit.dart';
import '../suppliers/suppliers_controller.dart';
import 'invoices_controller.dart';

enum _FilterStatus { all, outstanding, overdue, paid }

/// How wide the checkbox column is when the list is in selection mode, so the
/// headings and the rows line up.
const double _selectionGutter = 46;

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
    final tokens = AppTokens.of(context);

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
    var overdueCount = 0;
    for (final inv in allVisible) {
      if (inv.statusAt(now) == InvoiceStatus.overdue) overdueCount++;
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
    final filtering =
        _filterSupplierId != null || _filterStatus != _FilterStatus.all || q.isNotEmpty;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: Insets.page,
            child: PageHeader(
              title: 'Invoices',
              subtitle:
                  '${invoices.length} ${invoices.length == 1 ? 'invoice' : 'invoices'} · ${DateFormat('EEEE, d MMMM yyyy').format(now)}',
              icon: Icons.receipt_long,
              accentIndex: 1,
              meta: <Widget>[
                MiniPill(
                  '$openCount still owing',
                  icon: Icons.account_balance_wallet_outlined,
                  dense: true,
                ),
                if (overdueCount > 0)
                  MiniPill(
                    '$overdueCount past due',
                    icon: Icons.warning_amber_rounded,
                    color: tokens.danger,
                    dense: true,
                  ),
              ],
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
            padding: const EdgeInsets.fromLTRB(Insets.xxl, Insets.lg, Insets.xxl, 0),
            child: FilterBar(
              delay: const Duration(milliseconds: 70),
              children: <Widget>[
                SearchField(
                  hint: 'Search invoices…',
                  onChanged: (v) => setState(() => _query = v),
                ),
                FilterSelect<String?>(
                  value: _filterSupplierId,
                  hint: 'All suppliers',
                  items: <DropdownMenuItem<String?>>[
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
                FilterSelect<_FilterStatus>(
                  wrapperKey: const Key('status-filter'),
                  value: _filterStatus,
                  hint: 'All statuses',
                  items: const <DropdownMenuItem<_FilterStatus>>[
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
                    () => _filterStatus = v ?? _FilterStatus.all,
                  ),
                ),
                _BarIconButton(
                  tooltip: 'Select invoices',
                  icon: Icons.checklist_rounded,
                  onPressed: sorted.isEmpty
                      ? null
                      : () => setState(() {
                            _selectionMode = true;
                            if (_selected.isEmpty) {
                              _selected.add(sorted.first.id);
                            }
                          }),
                ),
                if (filtering)
                  _BarIconButton(
                    tooltip: 'Clear filters',
                    icon: Icons.filter_alt_off_outlined,
                    onPressed: () => setState(() {
                      _query = '';
                      _filterSupplierId = null;
                      _filterStatus = _FilterStatus.all;
                    }),
                  ),
              ],
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
            padding: const EdgeInsets.fromLTRB(Insets.xxl, Insets.md, Insets.xxl, 0),
            child: _SummaryRow(
              totalOwing: totalOwing,
              overdue: overdue,
              openCount: openCount,
              visible: allVisible.length,
            ),
          ),
          const SizedBox(height: Insets.md),
          Expanded(
            child: sorted.isEmpty
                ? _EmptyInvoices(onAdd: () => context.go('/new'))
                : Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.xxl,
                      0,
                      Insets.xxl,
                      Insets.xxl,
                    ),
                    child: _InvoiceTable(
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
                      footer: _TableFooter(
                        shown: sorted.length,
                        total: invoices.length,
                        overdueCount: overdueCount,
                      ),
                    ),
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

/// The four figures that sit above the table. Each one is a way into the same
/// list, so they are buttons rather than pictures of numbers.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.totalOwing,
    required this.overdue,
    required this.openCount,
    required this.visible,
  });

  final int totalOwing;
  final int overdue;
  final int openCount;
  final int visible;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
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
            value: '$visible',
            icon: Icons.receipt_long_outlined,
            gradient: StatCard.primary,
            delay: const Duration(milliseconds: 330),
          ),
        ),
      ],
    );
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
    required this.footer,
  });

  final List<SupplierInvoice> invoices;
  final Map<String, String> supplierNames;
  final DateTime now;
  final bool selectionMode;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onEnterSelection;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return TableScaffold(
      header: _HeaderRow(selectionMode: selectionMode),
      footer: footer,
      body: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: invoices.length,
        itemBuilder: (context, index) {
          final inv = invoices[index];
          return _InvoiceRow(
            invoice: inv,
            supplierName: supplierNames[inv.supplierId] ?? 'Unknown',
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
    );
  }
}

/// The count of what is on screen and what is late, along the bottom of the
/// table. No figures here: the columns above already carry the money.
class _TableFooter extends StatelessWidget {
  const _TableFooter({
    required this.shown,
    required this.total,
    required this.overdueCount,
  });

  final int shown;
  final int total;
  final int overdueCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    return Row(
      children: <Widget>[
        Icon(
          Icons.filter_alt_outlined,
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
            style: texts.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (overdueCount > 0)
          Text(
            '$overdueCount past due',
            style: texts.labelSmall?.copyWith(
              color: AppTokens.of(context).danger,
              fontWeight: FontWeight.w800,
            ),
          ),
      ],
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.selectionMode});

  final bool selectionMode;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        if (selectionMode) const SizedBox(width: _selectionGutter),
        const ColumnHeading('Supplier', flex: 22),
        const ColumnHeading('Invoice No', flex: 13),
        const ColumnHeading('Due', flex: 10),
        const ColumnHeading('Total (GH₵)', flex: 10, trailing: true),
        const ColumnHeading('Paid (GH₵)', flex: 10, trailing: true),
        const ColumnHeading('Balance (GH₵)', flex: 10, trailing: true),
        const ColumnHeading('Status', flex: 12),
      ],
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
    final texts = Theme.of(context).textTheme;
    final status = invoice.statusAt(now);

    return HoverRow(
      onTap: onTap,
      onSecondaryTap: onSecondaryTap,
      selected: selected,
      stripe: StatusBadge.colorOf(status),
      child: Row(
        children: <Widget>[
          if (selectionMode)
            SizedBox(
              width: _selectionGutter,
              child: Checkbox(
                value: selected,
                onChanged: (_) => onToggle(),
              ),
            ),
          TableCellBox(
            flex: 22,
            child: Text(
              supplierName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: texts.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          TableCellBox(
            flex: 13,
            child: Text(
              invoice.invoiceNumber,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: texts.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          TableCellBox(
            flex: 10,
            child: Text(
              formatDate(invoice.dueDate),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TableCellBox(
            flex: 10,
            align: CrossAxisAlignment.end,
            child: Money(invoice.totalPesewas, tone: MoneyTone.normal),
          ),
          TableCellBox(
            flex: 10,
            align: CrossAxisAlignment.end,
            child: Money(invoice.amountPaidPesewas, tone: MoneyTone.quiet),
          ),
          TableCellBox(
            flex: 10,
            align: CrossAxisAlignment.end,
            child: Money(
              invoice.balancePesewas,
              tone: MoneyTone.strong,
              color: invoice.owesMoney ? scheme.error : null,
              emphasiseWhenZero: true,
            ),
          ),
          TableCellBox(
            flex: 12,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: StatusBadge(status: status),
          ),
        ],
      ),
    );
  }
}

/// The square action at the end of the filter bar, sized to sit level with the
/// fields beside it.
class _BarIconButton extends StatelessWidget {
  const _BarIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.onSurface.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 20,
              color: onPressed == null
                  ? scheme.onSurfaceVariant.withValues(alpha: 0.4)
                  : scheme.onSurfaceVariant,
            ),
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
      padding: const EdgeInsets.fromLTRB(Insets.xxl, Insets.md, Insets.xxl, 0),
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
            children: <Widget>[
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
