import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'features/payments/payments_controller.dart';
import 'features/settings/app_preferences_controller.dart';
import 'models/app_preferences.dart';

class App extends ConsumerWidget {
  const App({super.key});

  /// The app's own choice of light and dark, translated for Flutter.
  static ThemeMode _modeOf(AppTheme theme) {
    switch (theme) {
      case AppTheme.dark:
        return ThemeMode.dark;
      case AppTheme.light:
        return ThemeMode.light;
      case AppTheme.system:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps the payment ledger loaded and in step with the invoices, so every
    // peso paid is explained by a record.
    ref.watch(paymentsProvider);
    // Watched, not read: this is what repaints the whole app when someone
    // changes the light in Settings.
    final preferences = ref.watch(appPreferencesProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'PFA Pharmacy Invoice Tracker',
      theme: buildTheme(),
      darkTheme: buildDarkTheme(),
      // The panes are glass over a night sky, so the sky is the default. The
      // light theme is still a first-class citizen and the settings page
      // switches between them.
      themeMode: _modeOf(preferences.theme),
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
