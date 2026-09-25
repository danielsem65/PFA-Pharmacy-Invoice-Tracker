import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';

/// Big enough for the invoice tables side by side, small enough to sit next to
/// another window without swallowing the screen.
const _openingSize = Size(1280, 820);
const _smallestSize = Size(980, 640);

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
