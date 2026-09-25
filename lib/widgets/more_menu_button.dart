import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../features/updates/update_dialog.dart';
import 'export_actions.dart';

class MoreMenuButton extends ConsumerWidget {
  const MoreMenuButton({super.key, this.color});

  final Color? color;

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
      icon: Icon(Icons.more_vert, color: color),
      onSelected: (action) {
        switch (action) {
          case _MenuAction.exportZip:
            exportZip(context, ref);
            break;
          case _MenuAction.restore:
            restoreBackup(context, ref);
            break;
          case _MenuAction.exportCsvInvoices:
            exportCsv(context, ref, invoices: true);
            break;
          case _MenuAction.exportCsvSuppliers:
            exportCsv(context, ref, invoices: false);
            break;
          case _MenuAction.checkUpdates:
            runUpdateFlow(context, ref);
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
}

enum _MenuAction {
  exportZip,
  restore,
  exportCsvInvoices,
  exportCsvSuppliers,
  checkUpdates,
  about,
}