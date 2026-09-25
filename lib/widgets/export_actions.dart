import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/backup_service.dart';
import '../features/invoices/invoices_controller.dart';
import '../features/suppliers/suppliers_controller.dart';

const kInvoicesCsvType = XTypeGroup(
  label: 'CSV',
  extensions: ['csv'],
);

const kZipType = XTypeGroup(
  label: 'ZIP backup',
  extensions: ['zip'],
);

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
    await ref.read(backupServiceProvider).exportZip(path.path, invoiceIds: invoiceIds);
    if (!context.mounted) return;
    toast(context, invoiceIds == null ? 'Backup saved.' : 'Export saved.');
  } catch (e) {
    if (context.mounted) toast(context, 'Export failed: $e');
  }
}

Future<void> exportCsv(
  BuildContext context,
  WidgetRef ref, {
  required bool invoices,
  Set<String>? invoiceIds,
}) async {
  final label = invoices ? 'Invoices' : 'Suppliers';
  final path = await getSaveLocation(
    suggestedName: 'InvoiceTracker_${label}_${_stamp()}.csv',
    acceptedTypeGroups: const [kInvoicesCsvType],
  );
  if (path == null) return;
  try {
    final service = ref.read(backupServiceProvider);
    String content;
    if (invoices) {
      final suppliers = ref.read(suppliersProvider);
      String nameOf(String id) {
        for (final s in suppliers) {
          if (s.id == id) return s.name;
        }
        return 'Unknown';
      }

      final allInvoices = ref.read(invoicesProvider);
      final selected = invoiceIds == null
          ? allInvoices
          : allInvoices.where((i) => invoiceIds.contains(i.id)).toList();
      content = service.invoicesCsv(selected, nameOf);
    } else {
      content = service.suppliersCsv(ref.read(suppliersProvider));
    }
    await File(path.path).writeAsString(content, flush: true);
    if (!context.mounted) return;
    toast(context, '$label exported.');
  } catch (e) {
    if (context.mounted) toast(context, 'Export failed: $e');
  }
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
        'suppliers and receipts.\n\nA safety backup of your current data '
        'will be saved first:\n$safety',
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

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}