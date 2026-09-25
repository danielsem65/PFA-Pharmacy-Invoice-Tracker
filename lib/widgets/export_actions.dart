import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/backup_service.dart';
import '../data/excel_service.dart';
import '../features/invoices/invoices_controller.dart';
import '../features/products/products_controller.dart';
import '../features/suppliers/suppliers_controller.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../models/supplier_invoice.dart';
import 'toast.dart';

const kInvoicesCsvType = XTypeGroup(
  label: 'CSV',
  extensions: ['csv'],
);

const kExcelType = XTypeGroup(
  label: 'Excel workbook',
  extensions: ['xlsx'],
);

const kZipType = XTypeGroup(
  label: 'ZIP backup',
  extensions: ['zip'],
);

String _supplierName(List<Supplier> suppliers, String id) {
  for (final s in suppliers) {
    if (s.id == id) return s.name;
  }
  return 'Unknown';
}

Future<void> exportZip(
  BuildContext context,
  WidgetRef ref, {
  Set<String>? invoiceIds,
}) async {
  final suggested = 'InvoiceTracker_Backup_${_stamp()}.zip';
  final path = await getSaveLocation(
    suggestedName: suggested,
    acceptedTypeGroups: const [kZipType],
  );
  if (path == null) return;
  try {
    await ref
        .read(backupServiceProvider)
        .exportZip(path.path, invoiceIds: invoiceIds);
    if (!context.mounted) return;
    toast(context, invoiceIds == null ? 'Backup saved.' : 'Export saved.');
  } catch (e) {
    if (context.mounted) toast(context, 'Export failed: $e');
  }
}

/// Writes [content] to a user-chosen CSV path.
Future<bool> _writeCsv(
  BuildContext context,
  String suggestedName,
  String content,
  String doneMessage,
) async {
  final path = await getSaveLocation(
    suggestedName: suggestedName,
    acceptedTypeGroups: const [kInvoicesCsvType],
  );
  if (path == null) return false;
  try {
    await File(path.path).writeAsString(content, flush: true);
    if (!context.mounted) return false;
    toast(context, doneMessage);
    return true;
  } catch (e) {
    if (context.mounted) toast(context, 'Export failed: $e');
    return false;
  }
}

Future<void> exportCsv(
  BuildContext context,
  WidgetRef ref, {
  required bool invoices,
  Set<String>? invoiceIds,
  List<SupplierInvoice>? invoiceScope,
}) async {
  final label = invoices ? 'Invoices' : 'Suppliers';
  if (!invoices) {
    await _writeCsv(
      context,
      'InvoiceTracker_${label}_${_stamp()}.csv',
      ref.read(backupServiceProvider).suppliersCsv(
        ref.read(suppliersProvider),
      ),
      '$label exported.',
    );
    return;
  }

  // A visible screen passes the rows it is currently showing so the export
  // matches the search and filters on screen; the ⋮ menu passes nothing and
  // therefore exports everything.
  final all = ref.read(invoicesProvider);
  final selected = invoiceIds != null
      ? all.where((i) => invoiceIds.contains(i.id)).toList()
      : invoiceScope ?? all;

  final suppliers = ref.read(suppliersProvider);
  final done = selected.length == all.length && invoiceScope == null
      ? 'Invoices exported (${all.length}).'
      : 'Exported ${selected.length} of ${all.length} invoices.';
  await _writeCsv(
    context,
    'InvoiceTracker_${label}_${_stamp()}.csv',
    ref.read(backupServiceProvider).invoicesCsv(
      selected,
      (id) => _supplierName(suppliers, id),
    ),
    done,
  );
}

/// Writes a real .xlsx workbook: a summary, the invoices, all suppliers and
/// all products. Money and dates are written as numbers and dates, so the
/// file can be totalled and sorted in Excel.
///
/// A visible screen passes the rows it is showing so the Invoices sheet matches
/// the search and filters on screen; suppliers and products are always
/// complete so the workbook still describes the whole pharmacy.
Future<void> exportExcel(
  BuildContext context,
  WidgetRef ref, {
  Set<String>? invoiceIds,
  List<SupplierInvoice>? invoiceScope,
}) async {
  final all = ref.read(invoicesProvider);
  final selected = invoiceIds != null
      ? all.where((i) => invoiceIds.contains(i.id)).toList()
      : invoiceScope ?? all;
  final suppliers = ref.read(suppliersProvider);
  final products = ref.read(productsProvider);

  final path = await getSaveLocation(
    suggestedName: 'InvoiceTracker_Workbook_${_stamp()}.xlsx',
    acceptedTypeGroups: const [kExcelType],
  );
  if (path == null) return;
  try {
    final bytes = buildWorkbookBytes(
      invoices: selected,
      suppliers: suppliers,
      products: products,
      supplierNameOf: (id) => _supplierName(suppliers, id),
    );
    await File(path.path).writeAsBytes(bytes, flush: true);
    if (!context.mounted) return;
    toast(
      context,
      'Excel workbook saved — ${selected.length} '
      '${selected.length == 1 ? 'invoice' : 'invoices'}, '
      '${suppliers.length} suppliers, ${products.length} products.',
    );
  } catch (e) {
    if (context.mounted) toast(context, 'Export failed: $e');
  }
}

Future<void> exportProductsCsv(
  BuildContext context,
  WidgetRef ref, {
  List<Product>? productScope,
}) async {
  final products = productScope ?? ref.read(productsProvider);
  await _writeCsv(
    context,
    'InvoiceTracker_Products_${_stamp()}.csv',
    ref.read(backupServiceProvider).productsCsv(products),
    'Products exported (${products.length}).',
  );
}

Future<void> restoreBackup(BuildContext context, WidgetRef ref) async {
  final path = await openFile(acceptedTypeGroups: const [kZipType]);
  if (path == null) return;
  final support = await getApplicationSupportDirectory();
  final backupDir = p.join(support.path, 'backups');
  await Directory(backupDir).create(recursive: true);
  final safety = p.join(backupDir, 'auto_${_stamp()}.zip');

  if (!context.mounted) return;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Restore backup?'),
      content: Text(
        'Importing this backup will REPLACE all current invoices, '
        'suppliers, products and receipts.\n\nA safety backup of your current '
        'data will be saved first:\n$safety',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Restore'),
        ),
      ],
    ),
  );

  if (ok != true || !context.mounted) return;
  try {
    await ref.read(backupServiceProvider).exportZip(safety);
    await ref.read(backupServiceProvider).importZip(path.path);
    ref.invalidate(suppliersProvider);
    ref.invalidate(invoicesProvider);
    ref.invalidate(productsProvider);
    if (context.mounted) toast(context, 'Backup restored.');
  } catch (e) {
    if (context.mounted) toast(context, 'Restore failed: $e');
  }
}

String _stamp() {
  final now = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${now.year}${two(now.month)}${two(now.day)}_'
      '${two(now.hour)}${two(now.minute)}${two(now.second)}';
}
