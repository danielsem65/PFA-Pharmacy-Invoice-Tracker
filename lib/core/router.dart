import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_version.dart';
import '../data/app_database.dart';
import '../features/invoices/invoice_detail_screen.dart';
import '../features/invoices/invoice_form_screen.dart';
import '../features/invoices/invoices_screen.dart';
import '../features/import/import_excel_screen.dart';
import '../features/overview/overview_screen.dart';
import '../features/payments/payment_form_screen.dart';
import '../features/payments/payments_screen.dart';
import '../features/products/product_form_screen.dart';
import '../features/products/products_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/suppliers/supplier_form_screen.dart';
import '../features/suppliers/suppliers_screen.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/aurora_background.dart';
import '../widgets/shortcuts_sheet.dart';
import '../widgets/toast.dart';
import '../widgets/window_caption.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Where the shell lands when the app opens. Invoices first: this is the page
/// the app is for, and the overview is one click away.
const String kLandingRoute = '/';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: kLandingRoute,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        // The order of these branches is the order of the sidebar's items, and
        // a nav item passes its own position straight to goBranch.
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/overview',
                builder: (context, state) => const OverviewScreen(),
              ),
            ],
          ),
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
                  GoRoute(
                    path: 'import',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const ImportExcelScreen(),
                  ),
                  GoRoute(
                    path: 'settings',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const SettingsScreen(),
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
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/products',
                builder: (context, state) => const ProductsScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) =>
                        const ProductFormScreen(),
                  ),
                  GoRoute(
                    path: ':id/edit',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => ProductFormScreen(
                      productId: state.pathParameters['id'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/payments',
                builder: (context, state) => const PaymentsScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const PaymentFormScreen(),
                  ),
                  GoRoute(
                    path: 'new/:supplierId',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => PaymentFormScreen(
                      supplierId: state.pathParameters['supplierId'],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('That page does not exist.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.go(kLandingRoute),
              child: const Text('Back to invoices'),
            ),
          ],
        ),
      ),
    ),
  );
});

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// Folded down to a strip of icons, so the wide tables get the room.
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    // Damaged-data recovery is reported once, from one place, rather than each
    // screen re-discovering it.
    ref.listenManual<String?>(dataWarningProvider, (previous, next) {
      if (next == null || next == previous) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        toast(context, next);
        ref.read(dataWarningProvider.notifier).state = null;
      });
    });
  }

  void _goToBranch(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final version = ref.watch(appVersionProvider).valueOrNull ?? '';

    return Scaffold(
      body: Stack(
        children: <Widget>[
          // The sky sits behind everything; the translucent page colour lets a
          // little of it through the gaps between cards.
          const Positioned.fill(child: AuroraBackground()),
          AppShortcuts(
            onNewInvoice: () => context.go('/new'),
            onNewSupplier: () => context.go('/suppliers/new'),
            onNewProduct: () => context.go('/products/new'),
            onRecordPayment: () => context.go('/payments/new'),
            onImport: () => context.go('/import'),
            onSettings: () => context.go('/settings'),
            onGoTo: _goToBranch,
            onToggleSidebar: () =>
                setState(() => _collapsed = !_collapsed),
            child: Column(
              children: <Widget>[
                // The app draws its own title bar, so the window has no native
                // one. Tests have no window, so they do not get this either.
                if (AppWindowCaption.isSupported)
                  AppWindowCaption(
                    sidebarWidth: _collapsed
                        ? AppSidebar.collapsedWidth
                        : AppSidebar.expandedWidth,
                    caption: 'PFA Pharmacy Invoice Tracker',
                  ),
                Expanded(
                  child: Row(
                    children: <Widget>[
                      AppSidebar(
                        index: widget.navigationShell.currentIndex,
                        onSelect: _goToBranch,
                        collapsed: _collapsed,
                        version: version,
                        onToggleCollapsed: () =>
                            setState(() => _collapsed = !_collapsed),
                        onShowShortcuts: () => ShortcutsSheet.show(context),
                      ),
                      Expanded(child: widget.navigationShell),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
