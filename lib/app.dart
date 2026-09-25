import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'features/payments/payments_controller.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Turns any paid amount that was typed straight onto an invoice into a
    // payment record, so the ledger explains every peso from day one.
    ref.watch(paymentSyncProvider);
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