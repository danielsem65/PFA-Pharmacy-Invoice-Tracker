import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';

/// Small enough to sit beside another window without swallowing the desktop,
/// and still wide enough for the invoice tables. The floor sits a little under
/// the opening size so the opening size is always reachable.
const _openingSize = Size(950, 550);
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
