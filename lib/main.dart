import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';

/// The size the app was settled on by hand: wide enough for the invoice tables
/// to breathe, short enough to sit beside another window on a 1366x768 screen.
/// The floor sits under the opening size so the opening size is reachable.
const _openingSize = Size(1160, 615);
const _smallestSize = Size(900, 500);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final options = WindowOptions(
    size: _openingSize,
    minimumSize: _smallestSize,
    center: true,
    title: 'PFA Pharmacy Invoice Tracker',
    windowButtonVisibility: true,
  );
  windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  runApp(const ProviderScope(child: App()));
}
