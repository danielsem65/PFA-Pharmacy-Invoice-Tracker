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
        ?.name ?? 'Unknown supplier';
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
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              inv.invoiceNumber,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
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
                      const SizedBox(height: 16),
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
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _row(context, 'Supplier', supplierName),
                _row(context, 'Invoice No', inv.invoiceNumber),
                if (inv.reference.isNotEmpty)
                  _row(context, 'Ref / PO', inv.reference),
                if (inv.description.isNotEmpty)
                  _row(context, 'Description', inv.description),
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
                if (inv.receipts.isNotEmpty) ...[
                  const Divider(height: 24),
                  Text(
                    'Receipts (${inv.receipts.length})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final name in inv.receipts)
                        ActionChip(
                          avatar: const Icon(Icons.image_outlined, size: 18),
                          label: Text(_displayName(name)),
                          onPressed: () => _openReceipt(context, ref, inv.id),
                        ),
                    ],
                  ),
                ],
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

  void _openReceipt(BuildContext context, WidgetRef ref, String invoiceId) {
    // The receipt names are resolved from storage; open the first attached.
    final invoice = ref
        .read(invoicesProvider)
        .where((i) => i.id == invoiceId)
        .firstOrNull;
    final name = invoice?.receipts.firstOrNull;
    if (name == null) return;
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
              width: 560,
              height: 420,
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