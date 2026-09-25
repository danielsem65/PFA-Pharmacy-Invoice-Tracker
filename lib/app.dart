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
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}