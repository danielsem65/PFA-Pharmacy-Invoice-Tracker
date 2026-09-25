import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/invoices/invoice_detail_screen.dart';
import '../features/invoices/invoice_form_screen.dart';
import '../features/invoices/invoices_screen.dart';
import '../features/suppliers/supplier_form_screen.dart';
import '../features/suppliers/suppliers_screen.dart';
import '../widgets/app_sidebar.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const InvoicesScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) =>
                        const InvoiceFormScreen(),
                  ),
                  GoRoute(
                    path: 'invoices/:id',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => InvoiceDetailScreen(
                      invoiceId: state.pathParameters['id']!,
                    ),
                  ),
                  GoRoute(
                    path: 'invoices/:id/edit',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => InvoiceFormScreen(
                      invoiceId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/suppliers',
                builder: (context, state) => const SuppliersScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) =>
                        const SupplierFormScreen(),
                  ),
                  GoRoute(
                    path: ':id/edit',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => SupplierFormScreen(
                      supplierId: state.pathParameters['id'],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Row(
        children: [
          AppSidebar(
            index: navigationShell.currentIndex,
            onSelect: (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}