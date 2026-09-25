import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/receipt_storage.dart';
import '../../models/supplier_invoice.dart';
import '../../widgets/status_badge.dart';
import 'invoices_controller.dart';
import '../suppliers/suppliers_controller.dart';

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
        appBar: AppBar(title: const Text('Invoice')),
        body: const Center(child: Text('Invoice not found.')),
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
      appBar: AppBar(
        title: Text(inv.invoiceNumber),
        actions: [
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
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _Hero(invoice: inv, supplierName: supplierName, status: status),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 760;
                    final details = [
                      _row(context, 'Supplier', supplierName),
                      _row(context, 'Invoice No', inv.invoiceNumber),
                      if (inv.reference.isNotEmpty)
                        _row(context, 'Ref / PO', inv.reference),
                      if (inv.description.isNotEmpty)
                        _row(context, 'Description', inv.description),
                      if (inv.lines.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _ItemsCard(invoice: inv),
                      ],
                      const Divider(height: 24),
                      _row(context, 'Invoice Date', formatDate(inv.invoiceDate)),
                      _row(context, 'Received', formatDate(inv.receivedDate)),
                      _row(context, 'Due', formatDate(inv.dueDate)),
                      _row(context, 'Status', status.label),
                      const Divider(height: 24),
                      _row(context, 'Amount', formatPesewas(inv.amountPesewas)),
                      if (inv.taxRatePercent > 0)
                        _row(
                          context,
                          'Tax (${inv.taxRatePercent}%)',
                          formatPesewas(inv.taxPesewas),
                        ),
                      _row(context, 'Total', formatPesewas(inv.totalPesewas)),
                      _row(
                        context,
                        'Paid',
                        formatPesewas(inv.amountPaidPesewas),
                      ),
                      if (inv.paidDate != null)
                        _row(context, 'Paid Date', formatDate(inv.paidDate!)),
                      _row(context, 'Payment method', inv.paymentMethod),
                      _row(context, 'Balance', formatPesewas(inv.balancePesewas)),
                      if (inv.notes.isNotEmpty) ...[
                        const Divider(height: 24),
                        _row(context, 'Notes', inv.notes),
                      ],
                    ];

                    final side = <Widget>[
                      _AmountWordsCard(invoice: inv),
                      if (inv.receipts.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _ReceiptsCard(invoice: inv, ref: ref, onOpen: _openReceipt),
                      ],
                    ];

                    if (!wide) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [...details, ...side],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: details,
                          ),
                        ),
                        const SizedBox(width: 24),
                        SizedBox(
                          width: 340,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: side,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final texts = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: texts.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: texts.bodyLarge)),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final ok = await showDialog<bool>(
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
    showDialog<void>(
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

class _Hero extends StatelessWidget {
  const _Hero({
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B3B52), Color(0xFF0E7490)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E7490).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        inv.invoiceNumber,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    StatusBadge(status: status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  supplierName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                inv.owesMoney ? 'OUTSTANDING' : 'SETTLED',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                formatPesewas(inv.balancePesewas),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AmountWordsCard extends StatelessWidget {
  const _AmountWordsCard({required this.invoice});

  final SupplierInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    final inv = invoice;

    Widget words(String label, IconData icon, int pesewas) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: texts.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AMOUNT IN WORDS',
            style: texts.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const Divider(height: 24),
          words('TOTAL', Icons.receipt_long_outlined, inv.totalPesewas),
          if (inv.owesMoney) ...[
            const Divider(height: 16),
            words('BALANCE', Icons.account_balance_wallet_outlined, inv.balancePesewas),
          ],
        ],
      ),
    );
  }
}

class _ReceiptsCard extends StatelessWidget {
  const _ReceiptsCard({
    required this.invoice,
    required this.ref,
    required this.onOpen,
  });

  final SupplierInvoice invoice;
  final WidgetRef ref;
  final void Function(BuildContext context, WidgetRef ref, String name) onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Receipts (${invoice.receipts.length})',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in invoice.receipts)
                ActionChip(
                  avatar: const Icon(Icons.image_outlined, size: 18),
                  label: Text(_displayName(name)),
                  onPressed: () => onOpen(context, ref, name),
                ),
            ],
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

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.invoice});

  final SupplierInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;

    Widget header(String label, {bool right = false}) => Text(
          label,
          textAlign: right ? TextAlign.right : TextAlign.left,
          style: texts.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        );

    Widget cell(
      String text, {
      bool right = false,
      TextStyle? style,
    }) => Text(
      text,
      textAlign: right ? TextAlign.right : TextAlign.left,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style ?? texts.bodyMedium,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Items (${invoice.lines.length})',
            style: texts.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const Divider(height: 22),
          Row(
            children: [
              Expanded(flex: 4, child: header('Product')),
              Expanded(flex: 2, child: header('Qty', right: true)),
              Expanded(flex: 2, child: header('Price/box', right: true)),
              Expanded(flex: 2, child: header('Amount', right: true)),
            ],
          ),
          const SizedBox(height: 6),
          for (final line in invoice.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: cell(
                      line.name,
                      style: texts.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        cell('${line.boxes} × ${line.piecesPerBox}',
                            right: true),
                        cell(
                          '${line.pieceCount} items',
                          right: true,
                          style: texts.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: cell(
                      '${formatPesewas(line.pricePerBoxPesewas)}/box',
                      right: true,
                      style: texts.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: cell(
                      formatPesewas(line.totalPesewas),
                      right: true,
                      style: texts.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Subtotal',
                  style: texts.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                formatPesewas(invoice.lineItemsTotalPesewas),
                style: texts.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }
}