import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/receipt_storage.dart';
import '../../models/supplier_invoice.dart';
import '../../widgets/desktop_form.dart';
import '../../widgets/glass_panel.dart';
import '../../widgets/more_menu_button.dart';
import '../../widgets/page_header.dart';
import '../../widgets/print_invoice_action.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/glass_dialog.dart';
import '../../widgets/status_badge.dart';
import 'invoices_controller.dart';
import '../suppliers/suppliers_controller.dart';

/// One invoice, read end to end. It is built from the same parts as the invoice
/// list — the page header, the row of figures, and the frosted panels with their
/// tinted heading strips — so opening an invoice feels like a deeper page of the
/// list rather than a different application.
class InvoiceDetailScreen extends ConsumerWidget {
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(invoicesProvider);
    final suppliers = ref.watch(suppliersProvider);
    final now = DateTime.now();

    SupplierInvoice? invoice;
    for (final i in invoices) {
      if (i.id == invoiceId) {
        invoice = i;
        break;
      }
    }

    if (invoice == null) {
      return Scaffold(
        body: SafeArea(
          child: EmptyState(
            icon: Icons.search_off,
            title: 'Invoice not found',
            message: 'It may have been deleted from another page.',
            action: FilledButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.receipt_long, size: 18),
              label: const Text('Back to invoices'),
            ),
          ),
        ),
      );
    }

    final inv = invoice;

    final supplierName = suppliers
            .where((s) => s.id == inv.supplierId)
            .firstOrNull
            ?.name ??
        'Unknown supplier';
    final status = inv.statusAt(now);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
              child: PageHeader(
                title: inv.invoiceNumber,
                subtitle: '$supplierName · Due ${formatDate(inv.dueDate)}',
                icon: Icons.receipt_long,
                leading: IconButton(
                  key: const Key('invoice-back'),
                  tooltip: 'Back to invoices',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                ),
                actions: <Widget>[
                  // Scoped to this invoice, so an export started from here
                  // cannot quietly sweep up the whole database.
                  MoreMenuButton(visibleInvoices: <SupplierInvoice>[inv]),
                  IconButton(
                    tooltip: 'Edit',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => context.go('/invoices/${inv.id}/edit'),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(context, ref, inv.id),
                  ),
                  Tooltip(
                    message: 'Print',
                    child: FilledButton.icon(
                      key: const Key('print-invoice'),
                      icon: const Icon(Icons.print_outlined, size: 18),
                      label: const Text('Print'),
                      onPressed: () => printInvoice(context, ref, inv),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
              child: _Figures(invoice: inv, status: status),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  final main = <Widget>[
                    _DetailsPanel(
                      invoice: inv,
                      supplierName: supplierName,
                      status: status,
                    ),
                    const SizedBox(height: 16),
                    _AmountsPanel(invoice: inv),
                    if (inv.lines.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 16),
                      _ItemsPanel(invoice: inv),
                    ],
                  ];
                  final side = <Widget>[
                    _AmountWordsPanel(invoice: inv),
                    if (inv.receipts.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 16),
                      _ReceiptsPanel(invoice: inv, ref: ref, onOpen: _openReceipt),
                    ],
                  ];

                  const padding = EdgeInsets.fromLTRB(24, 0, 24, 20);
                  if (box.maxWidth < 900) {
                    return SingleChildScrollView(
                      padding: padding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: withGaps([...main, ...side], 16),
                      ),
                    );
                  }
                  return SingleChildScrollView(
                    padding: padding,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          flex: 7,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: withGaps(main, 16),
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 320,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: withGaps(side, 16),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final ok = await showGlassDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete invoice?'),
        content: const Text('This cannot be undone.'),
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
    if (ok == true && context.mounted) {
      await ref.read(invoicesProvider.notifier).remove(id);
      if (context.mounted) context.pop();
    }
  }

  void _openReceipt(BuildContext context, WidgetRef ref, String name) {
    showGlassDialog<void>(
      context: context,
      builder: (context) => FutureBuilder<File>(
        future: ref
            .read(receiptStorageProvider)
            .receiptPath(name)
            .then((p) => File(p)),
        builder: (context, snapshot) {
          final file = snapshot.data;
          return AlertDialog(
            title: Text(_displayName(name)),
            content: SizedBox(
              width: 720,
              height: 520,
              child: file == null
                  ? const Center(child: CircularProgressIndicator())
                  : file.existsSync()
                      ? Image.file(file)
                      : const Center(child: Text('Receipt not found.')),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _displayName(String stored) {
    final idx = stored.indexOf('_');
    if (idx == -1) return stored;
    return stored.substring(idx + 1).replaceAll('_', ' ');
  }
}

/// The row of figures under the header: what the invoice is worth, what has been
/// paid against it, what is left, and when it falls due. Two tiles on a narrow
/// window, four on a wide one.
class _Figures extends StatelessWidget {
  const _Figures({required this.invoice, required this.status});

  final SupplierInvoice invoice;
  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    final inv = invoice;
    final tiles = <Widget>[
      StatCard(
        label: 'Total',
        value: formatPesewas(inv.totalPesewas),
        icon: Icons.receipt_long_outlined,
        gradient: StatCard.primary,
        delay: const Duration(milliseconds: 120),
      ),
      StatCard(
        label: 'Paid',
        value: formatPesewas(inv.amountPaidPesewas),
        icon: Icons.payments_outlined,
        gradient: StatCard.neutral,
        delay: const Duration(milliseconds: 190),
      ),
      StatCard(
        label: 'Balance',
        value: formatPesewas(inv.balancePesewas),
        icon: inv.owesMoney
            ? Icons.account_balance_wallet_outlined
            : Icons.verified_outlined,
        gradient: inv.owesMoney ? StatCard.danger : StatCard.primary,
        delay: const Duration(milliseconds: 260),
      ),
      StatCard(
        label: 'Due',
        value: formatDate(inv.dueDate),
        icon: Icons.event_outlined,
        gradient: StatCard.neutral,
        delay: const Duration(milliseconds: 330),
      ),
    ];

    return LayoutBuilder(
      builder: (context, box) {
        final perRow = box.maxWidth >= 720 ? 4 : 2;
        return Column(
          children: <Widget>[
            for (var i = 0; i < tiles.length; i += perRow) ...<Widget>[
              if (i > 0) const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  for (var j = i; j < i + perRow && j < tiles.length; j++) ...<Widget>[
                    if (j > i) const SizedBox(width: 12),
                    Expanded(child: tiles[j]),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// The metadata strip: who it is from, what it covers, and when it is due.
class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel({
    required this.invoice,
    required this.supplierName,
    required this.status,
  });

  final SupplierInvoice invoice;
  final String supplierName;
  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    final inv = invoice;
    final rows = <({String label, String value})>[
      (label: 'Supplier', value: supplierName),
      (label: 'Invoice No', value: inv.invoiceNumber),
      if (inv.reference.isNotEmpty) (label: 'Ref / PO', value: inv.reference),
      if (inv.description.isNotEmpty)
        (label: 'Description', value: inv.description),
      (label: 'Invoice Date', value: formatDate(inv.invoiceDate)),
      (label: 'Received', value: formatDate(inv.receivedDate)),
      (label: 'Due', value: formatDate(inv.dueDate)),
      (label: 'Payment method', value: inv.paymentMethod),
      if (inv.paidDate != null)
        (label: 'Paid Date', value: formatDate(inv.paidDate!)),
      if (inv.notes.isNotEmpty) (label: 'Notes', value: inv.notes),
    ];

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PanelHeader(
            child: PanelTitle(
              title: 'Details',
              icon: Icons.info_outline,
              trailing: StatusBadge(status: status),
            ),
          ),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    flex: 4,
                    child: Text(
                      row.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: Text(
                      row.value,
                      textAlign: TextAlign.right,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The money, stacked the way it is worked out: amount, VAT, total, then what
/// has been paid and what is still owed.
class _AmountsPanel extends StatelessWidget {
  const _AmountsPanel({required this.invoice});

  final SupplierInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    final inv = invoice;

    Widget row(String label, String value, {bool strong = false, Color? color}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: strong
                    ? texts.bodyMedium?.copyWith(fontWeight: FontWeight.w800)
                    : texts.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              value,
              style: (strong ? texts.titleMedium : texts.bodyMedium)?.copyWith(
                fontWeight: FontWeight.w800,
                color: color ?? scheme.onSurface,
              ),
            ),
          ],
        ),
      );
    }

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const PanelHeader(
            child: PanelTitle(
              title: 'Amounts',
              icon: Icons.calculate_outlined,
            ),
          ),
          row('Amount', formatPesewas(inv.amountPesewas)),
          if (inv.taxRatePercent > 0)
            row('VAT (${_trimRate(inv.taxRatePercent)}%)', formatPesewas(inv.taxPesewas)),
          row('Total', formatPesewas(inv.totalPesewas), strong: true, color: scheme.primary),
          const Divider(height: 1),
          row('Paid', formatPesewas(inv.amountPaidPesewas)),
          row(
            inv.owesMoney ? 'Balance due' : 'Balance settled',
            formatPesewas(inv.balancePesewas),
            strong: true,
            color: inv.owesMoney ? scheme.error : const Color(0xFF0F9D77),
          ),
        ],
      ),
    );
  }

  static String _trimRate(double rate) =>
      rate == rate.roundToDouble() ? '${rate.round()}' : '$rate';
}

/// The item lines, in the same column arrangement as the printed page.
class _ItemsPanel extends StatelessWidget {
  const _ItemsPanel({required this.invoice});

  final SupplierInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    final inv = invoice;
    final heading = panelHeadingStyle(context);

    Widget column(
      String label, {
      int flex = 1,
      bool right = false,
    }) =>
        Expanded(
          flex: flex,
          child: Text(
            label,
            textAlign: right ? TextAlign.right : TextAlign.left,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: heading,
          ),
        );

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PanelHeader(
            child: PanelTitle(
              title: 'Items (${inv.lines.length})',
              icon: Icons.inventory_2_outlined,
              trailing: Text(
                formatPesewas(inv.lineItemsTotalPesewas),
                style: texts.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: <Widget>[
                column('Product', flex: 4),
                column('Qty', flex: 2, right: true),
                column('Price/box', flex: 2, right: true),
                column('Amount', flex: 2, right: true),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
          for (final line in inv.lines)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    flex: 4,
                    child: Text(
                      line.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: texts.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text('${line.boxes} × ${line.piecesPerBox}'),
                        Text(
                          '${line.pieceCount} items',
                          style: texts.labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      formatPesewas(line.pricePerBoxPesewas),
                      textAlign: TextAlign.right,
                      style: texts.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      formatPesewas(line.totalPesewas),
                      textAlign: TextAlign.right,
                      style: texts.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Items subtotal',
                    style: texts.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  formatPesewas(inv.lineItemsTotalPesewas),
                  style: texts.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The total written out, for the part of the payment that has to be spelled.
class _AmountWordsPanel extends StatelessWidget {
  const _AmountWordsPanel({required this.invoice});

  final SupplierInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    final inv = invoice;

    Widget words(String label, IconData icon, int pesewas) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 15, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  label.toUpperCase(),
                  style: texts.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              moneyInWords(pesewas),
              style: texts.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
        ),
      );
    }

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const PanelHeader(
            child: PanelTitle(
              title: 'Amount in words',
              icon: Icons.spellcheck_outlined,
            ),
          ),
          words('Total', Icons.receipt_long_outlined, inv.totalPesewas),
          if (inv.owesMoney)
            words('Balance', Icons.account_balance_wallet_outlined, inv.balancePesewas),
        ],
      ),
    );
  }
}

/// The receipt images attached to the invoice, each one openable.
class _ReceiptsPanel extends StatelessWidget {
  const _ReceiptsPanel({
    required this.invoice,
    required this.ref,
    required this.onOpen,
  });

  final SupplierInvoice invoice;
  final WidgetRef ref;
  final void Function(BuildContext context, WidgetRef ref, String name) onOpen;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PanelHeader(
            child: PanelTitle(
              title: 'Receipts (${invoice.receipts.length})',
              icon: Icons.image_outlined,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final name in invoice.receipts)
                  ActionChip(
                    avatar: const Icon(Icons.image_outlined, size: 18),
                    label: Text(_displayName(name)),
                    onPressed: () => onOpen(context, ref, name),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _displayName(String stored) {
    final idx = stored.indexOf('_');
    if (idx == -1) return stored;
    return stored.substring(idx + 1).replaceAll('_', ' ');
  }
}
