import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'features/payments/payments_controller.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps the payment ledger loaded and in step with the invoices, so every
    // peso paid is explained by a record.
    ref.watch(paymentsProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'PFA Pharmacy Invoice Tracker',
      theme: buildTheme(),
      darkTheme: buildDarkTheme(),
      // The panes are glass over a night sky, so the sky is the default. The
      // light theme is still a first-class citizen and the settings page
      // switches between them.
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}