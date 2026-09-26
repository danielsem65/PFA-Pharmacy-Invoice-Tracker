import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/design.dart';
import '../core/theme.dart';
import 'glass_panel.dart';
import 'ui_kit.dart';

/// One row of the shortcuts sheet.
class _Shortcut {
  const _Shortcut(this.keys, this.what);

  final List<String> keys;
  final String what;
}

/// The keys the app answers to, and the sheet that lists them.
///
/// Wrapping the whole shell in [AppShortcuts] means a shortcut works from any
/// page, including from inside a form, without each screen wiring it up.
class AppShortcuts extends StatelessWidget {
  const AppShortcuts({
    super.key,
    required this.child,
    required this.onNewInvoice,
    required this.onNewSupplier,
    required this.onNewProduct,
    required this.onRecordPayment,
    required this.onImport,
    required this.onSettings,
    required this.onGoTo,
    required this.onToggleSidebar,
  });

  final Widget child;
  final VoidCallback onNewInvoice;
  final VoidCallback onNewSupplier;
  final VoidCallback onNewProduct;
  final VoidCallback onRecordPayment;
  final VoidCallback onImport;
  final VoidCallback onSettings;

  /// Takes a branch index, matching the order the sidebar lists them.
  final ValueChanged<int> onGoTo;
  final VoidCallback onToggleSidebar;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyI, control: true, shift: true):
            onNewInvoice,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true):
            onNewSupplier,
        const SingleActivator(LogicalKeyboardKey.keyD, control: true, shift: true):
            onNewProduct,
        const SingleActivator(LogicalKeyboardKey.keyP, control: true, shift: true):
            onRecordPayment,
        const SingleActivator(LogicalKeyboardKey.keyE, control: true, shift: true):
            onImport,
        const SingleActivator(LogicalKeyboardKey.comma, control: true):
            onSettings,
        const SingleActivator(LogicalKeyboardKey.keyB, control: true):
            onToggleSidebar,
        const SingleActivator(LogicalKeyboardKey.digit1, control: true):
            () => onGoTo(0),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true):
            () => onGoTo(1),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true):
            () => onGoTo(2),
        const SingleActivator(LogicalKeyboardKey.digit4, control: true):
            () => onGoTo(3),
        const SingleActivator(LogicalKeyboardKey.digit5, control: true):
            () => onGoTo(4),
      },
      child: child,
    );
  }
}

/// The sheet that lists every shortcut, grouped by what it is for.
class ShortcutsSheet extends StatelessWidget {
  const ShortcutsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (context) => const ShortcutsSheet(),
    );
  }

  static const List<_Shortcut> _creating = <_Shortcut>[
    _Shortcut(<String>['Ctrl', 'Shift', 'I'], 'New invoice'),
    _Shortcut(<String>['Ctrl', 'Shift', 'S'], 'New supplier'),
    _Shortcut(<String>['Ctrl', 'Shift', 'D'], 'New product'),
    _Shortcut(<String>['Ctrl', 'Shift', 'P'], 'Record payment'),
    _Shortcut(<String>['Ctrl', 'Shift', 'E'], 'Import from Excel'),
  ];

  static const List<_Shortcut> _moving = <_Shortcut>[
    _Shortcut(<String>['Ctrl', '1'], 'Go to Overview'),
    _Shortcut(<String>['Ctrl', '2'], 'Go to Invoices'),
    _Shortcut(<String>['Ctrl', '3'], 'Go to Suppliers'),
    _Shortcut(<String>['Ctrl', '4'], 'Go to Products'),
    _Shortcut(<String>['Ctrl', '5'], 'Go to Payments'),
    _Shortcut(<String>['Ctrl', 'B'], 'Fold the sidebar'),
    _Shortcut(<String>['Ctrl', ','], 'Settings'),
    _Shortcut(<String>['Esc'], 'Close a dialog'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;

    Widget group(String title, List<_Shortcut> rows) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title.toUpperCase(),
              style: texts.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 150,
                      child: Row(
                        children: <Widget>[
                          for (var i = 0; i < row.keys.length; i++) ...<Widget>[
                            if (i > 0)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 3),
                                child: Text(
                                  '+',
                                  style: TextStyle(
                                    color: Colors.white24,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            Kbd(row.keys[i]),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.what,
                        style: texts.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: GlassPanel(
          radius: AppTokens.of(context).radiusLg,
          child: Padding(
            padding: const EdgeInsets.all(Insets.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.keyboard_alt_outlined,
                      size: 20,
                      color: Aurora.teal,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Keyboard shortcuts',
                        style: texts.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      tooltip: 'Close',
                    ),
                  ],
                ),
                const SizedBox(height: Insets.lg),
                group('Making things', _creating),
                const SizedBox(height: Insets.xl),
                group('Getting around', _moving),
                const SizedBox(height: Insets.xl),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Everything stays on this computer. Nothing here '
                        'reaches the internet.',
                        style: texts.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
