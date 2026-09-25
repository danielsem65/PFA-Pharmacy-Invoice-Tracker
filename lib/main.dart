import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';

/// The window opens at a comfortable working size rather than filling the
/// screen: big enough for the invoice tables, small enough to sit beside other
/// windows. Where the display is smaller than that, it shrinks to fit.
const _preferredSize = Size(1280, 820);
const _smallestSize = Size(980, 640);
const _screenMargin = 96.0;

Future<Size> _openingSize() async {
  try {
    // The work area is the screen without the taskbar, so this never opens a
    // window whose buttons end up under the taskbar.
    final work = (await windowManager.getScreenInfo()).visiblePosition;
    return Size(
      math.min(_preferredSize.width, math.max(_smallestSize.width, work.width - _screenMargin)),
      math.min(_preferredSize.height, math.max(_smallestSize.height, work.height - _screenMargin)),
    );
  } catch (_) {
    return _preferredSize;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final opening = await _openingSize();
  final options = WindowOptions(
    size: opening,
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
