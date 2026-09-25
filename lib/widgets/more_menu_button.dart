import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/backup_service.dart';
import '../features/invoices/invoices_controller.dart';
import '../features/suppliers/suppliers_controller.dart';
import '../features/updates/update_dialog.dart';

class MoreMenuButton extends ConsumerWidget {
  const MoreMenuButton({super.key});

  static const _invoicesCsvType = XTypeGroup(
    label: 'CSV',
    extensions: ['csv'],
  );

  static const _zipType = XTypeGroup(
    label: 'ZIP backup',
    extensions: ['zip'],
  );

  Future<void> _exportZip(BuildContext context, WidgetRef ref) async {
    final suggested = 'InvoiceTracker_Backup_${_stamp()}.zip';
    final path = await getSaveLocation(
      suggestedName: suggested,
      acceptedTypeGroups: const [_zipType],
    );
    if (path == null) return;
    try {
      await ref.read(backupServiceProvider).exportZip(path.path);
      if (!context.mounted) return;
      _toast(context, 'Backup saved.');
    } catch (e) {
      if (context.mounted) _toast(context, 'Backup failed: $e');
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final path = await openFile(acceptedTypeGroups: const [_zipType]);
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
      if (context.mounted) _toast(context, 'Backup restored.');
    } catch (e) {
      if (context.mounted) _toast(context, 'Restore failed: $e');
    }
  }

  Future<void> _exportCsv(
    BuildContext context,
    WidgetRef ref, {
    required bool invoices,
  }) async {
    final label = invoices ? 'Invoices' : 'Suppliers';
    final path = await getSaveLocation(
      suggestedName: 'InvoiceTracker_${label}_${_stamp()}.csv',
      acceptedTypeGroups: const [_invoicesCsvType],
    );
    if (path == null) return;
    try {
      final service = ref.read(backupServiceProvider);
      final suppliers = ref.read(suppliersProvider);
      final allInvoices = ref.read(invoicesProvider);
      String content;
      if (invoices) {
        String nameOf(String id) {
          for (final s in suppliers) {
            if (s.id == id) return s.name;
          }
          return 'Unknown';
        }

        content = service.invoicesCsv(allInvoices, nameOf);
      } else {
        content = service.suppliersCsv(suppliers);
      }
      await File(path.path).writeAsString(content, flush: true);
      if (!context.mounted) return;
      _toast(context, '$label exported.');
    } catch (e) {
      if (context.mounted) _toast(context, 'Export failed: $e');
    }
  }

  void _checkUpdates(BuildContext context, WidgetRef ref) {
    runUpdateFlow(context, ref);
  }

  Future<void> _about(BuildContext context) async {
    String version = '1.0.0';
    try {
      final info = await PackageInfo.fromPlatform();
      version = info.version;
    } catch (_) {}
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PFA Pharmacy Invoice Tracker'),
        content: Text(
          'Version $version\n\n'
          'Offline supplier invoice tracker.\n'
          'All data stays on this PC — nothing is uploaded.\n\n'
          '© PFA Pharmacy',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_MenuAction>(
      tooltip: 'More',
      icon: const Icon(Icons.more_vert),
      onSelected: (action) {
        switch (action) {
          case _MenuAction.exportZip:
            _exportZip(context, ref);
            break;
          case _MenuAction.restore:
            _restore(context, ref);
            break;
          case _MenuAction.exportCsvInvoices:
            _exportCsv(context, ref, invoices: true);
            break;
          case _MenuAction.exportCsvSuppliers:
            _exportCsv(context, ref, invoices: false);
            break;
          case _MenuAction.checkUpdates:
            _checkUpdates(context, ref);
            break;
          case _MenuAction.about:
            _about(context);
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _MenuAction.exportZip,
          child: ListTile(
            leading: Icon(Icons.archive_outlined),
            title: Text('Export backup (ZIP)'),
          ),
        ),
        const PopupMenuItem(
          value: _MenuAction.restore,
          child: ListTile(
            leading: Icon(Icons.unarchive_outlined),
            title: Text('Restore backup…'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _MenuAction.exportCsvInvoices,
          child: ListTile(
            leading: Icon(Icons.table_chart_outlined),
            title: Text('Export CSV • Invoices'),
          ),
        ),
        const PopupMenuItem(
          value: _MenuAction.exportCsvSuppliers,
          child: ListTile(
            leading: Icon(Icons.table_chart_outlined),
            title: Text('Export CSV • Suppliers'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _MenuAction.checkUpdates,
          child: ListTile(
            leading: Icon(Icons.system_update_alt),
            title: Text('Check for updates'),
          ),
        ),
        const PopupMenuItem(
          value: _MenuAction.about,
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('About'),
          ),
        ),
      ],
    );
  }

  String _stamp() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _MenuAction {
  exportZip,
  restore,
  exportCsvInvoices,
  exportCsvSuppliers,
  checkUpdates,
  about,
}