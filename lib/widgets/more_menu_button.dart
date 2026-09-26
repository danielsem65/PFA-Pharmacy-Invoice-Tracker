import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_version.dart';
import '../features/updates/update_dialog.dart';
import '../models/product.dart';
import '../models/supplier_invoice.dart';
import 'export_actions.dart';

/// The ⋮ menu. Screens pass the rows they are currently showing so that
/// "Export CSV" matches the visible search and filters instead of silently
/// exporting the whole database.
class MoreMenuButton extends ConsumerWidget {
  const MoreMenuButton({
    super.key,
    this.color,
    this.visibleInvoices,
    this.visibleProducts,
  });

  final Color? color;

  /// Invoices currently listed on screen, or null for "everything".
  final List<SupplierInvoice>? visibleInvoices;

  /// Products currently listed on screen, or null for "everything".
  final List<Product>? visibleProducts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_MenuAction>(
      tooltip: 'More',
      icon: Icon(Icons.more_vert, color: color),
      onSelected: (action) {
        switch (action) {
          case _MenuAction.exportZip:
            exportZip(context, ref);
            break;
          case _MenuAction.restore:
            restoreBackup(context, ref);
            break;
          case _MenuAction.exportExcel:
            exportExcel(context, ref, invoiceScope: visibleInvoices);
            break;
          case _MenuAction.importExcel:
            context.go('/import');
            break;
          case _MenuAction.exportCsvInvoices:
            exportCsv(
              context,
              ref,
              invoices: true,
              invoiceScope: visibleInvoices,
            );
            break;
          case _MenuAction.exportCsvSuppliers:
            exportCsv(context, ref, invoices: false);
            break;
          case _MenuAction.exportCsvProducts:
            exportProductsCsv(context, ref, productScope: visibleProducts);
            break;
          case _MenuAction.settings:
            context.go('/settings');
            break;
          case _MenuAction.checkUpdates:
            runUpdateFlow(context, ref);
            break;
          case _MenuAction.about:
            _showAbout(context, ref);
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
          value: _MenuAction.exportExcel,
          child: ListTile(
            leading: Icon(Icons.grid_on),
            title: Text('Export Excel workbook'),
          ),
        ),
        const PopupMenuItem(
          value: _MenuAction.importExcel,
          child: ListTile(
            leading: Icon(Icons.upload_file),
            title: Text('Import invoices from Excel…'),
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
        const PopupMenuItem(
          value: _MenuAction.exportCsvProducts,
          child: ListTile(
            leading: Icon(Icons.table_chart_outlined),
            title: Text('Export CSV • Products'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _MenuAction.settings,
          child: ListTile(
            leading: Icon(Icons.tune),
            title: Text('Settings…'),
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

  void _showAbout(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider).valueOrNull;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PFA Pharmacy Invoice Tracker'),
        content: Text(
          'Version ${version ?? '…'}\n\n'
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
}

enum _MenuAction {
  exportZip,
  restore,
  exportExcel,
  importExcel,
  exportCsvInvoices,
  exportCsvSuppliers,
  exportCsvProducts,
  settings,
  checkUpdates,
  about,
}
