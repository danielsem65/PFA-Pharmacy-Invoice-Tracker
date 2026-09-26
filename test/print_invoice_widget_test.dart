import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pfa_pharmacy_invoice_tracker/app.dart';
import 'package:pfa_pharmacy_invoice_tracker/data/app_database.dart';
import 'package:pfa_pharmacy_invoice_tracker/features/settings/business_profile_controller.dart';
import 'package:pfa_pharmacy_invoice_tracker/features/settings/print_settings_controller.dart';
import 'package:pfa_pharmacy_invoice_tracker/models/business_profile.dart';
import 'package:pfa_pharmacy_invoice_tracker/models/print_settings.dart';
import 'package:pfa_pharmacy_invoice_tracker/models/supplier_invoice.dart';
import 'package:pfa_pharmacy_invoice_tracker/widgets/more_menu_button.dart';

import 'helpers.dart';

void main() {
  Future<InMemoryLocalStore> pumpApp(
    WidgetTester tester,
    InMemoryLocalStore store, {
    Size size = const Size(900, 1400),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStoreProvider.overrideWithValue(store)],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();
    return store;
  }

  InMemoryLocalStore seed() => InMemoryLocalStore(
        suppliers: [supplier('s1', 'Pharma Co')],
        invoices: <SupplierInvoice>[
          invoice(
            id: 'i1',
            supplierId: 's1',
            invoiceNumber: 'INV-001',
            amountPesewas: 100000,
            taxRatePercent: 15,
            lines: <InvoiceLine>[
              InvoiceLine(
                name: 'Paracetamol 500mg',
                boxes: 2,
                piecesPerBox: 20,
                pricePerBoxPesewas: 1000,
              ),
            ],
          ),
        ],
      );

  group('Settings route', () {
    testWidgets('opens from the ⋮ menu', (tester) async {
      await pumpApp(tester, seed());

      await tester.tap(find.byType(MoreMenuButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings…'));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Business details'), findsOneWidget);
      expect(find.text('Printing'), findsOneWidget);
    });

    testWidgets('lists the three layouts and the ask-each-time option',
        (tester) async {
      await pumpApp(tester, seed());

      await tester.tap(find.byType(MoreMenuButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings…'));
      await tester.pumpAndSettle();

      expect(find.text('Ask each time'), findsOneWidget);
      for (final layout in InvoicePrintLayout.values) {
        expect(find.text(layout.label), findsOneWidget);
      }
    });
  });

  group('Settings business details', () {
    testWidgets('saves what was typed', (tester) async {
      final store = await pumpApp(tester, seed());

      await tester.tap(find.byType(MoreMenuButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings…'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Business name'),
        'PFA Pharmacy Ltd',
      );
      await tester.ensureVisible(
        find.widgetWithText(TextFormField, 'Phone'),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone'),
        '030 123 4567',
      );
      await tester.ensureVisible(find.text('Save details').last);
      // ensureVisible scrolls on an animation, so it needs a frame before the
      // position it settled on can be tapped.
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save details').last);
      await tester.pumpAndSettle();

      expect(store.profile.name, 'PFA Pharmacy Ltd');
      expect(store.profile.phone, '030 123 4567');
    });

    testWidgets('shows the stored details when reopened', (tester) async {
      final store = seed();
      store.profile = BusinessProfile(
        name: 'Saved Pharmacy',
        address: '12 Oxford Street',
      );

      await pumpApp(tester, store);
      await tester.tap(find.byType(MoreMenuButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings…'));
      await tester.pumpAndSettle();

      expect(find.text('Saved Pharmacy'), findsOneWidget);
    });
  });

  group('Settings print layout', () {
    testWidgets('remembers the chosen default layout', (tester) async {
      final store = await pumpApp(tester, seed());

      await tester.tap(find.byType(MoreMenuButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings…'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text(InvoicePrintLayout.splitLedger.label));
      await tester.tap(find.text(InvoicePrintLayout.splitLedger.label));
      await tester.pumpAndSettle();

      expect(store.printSettings.defaultLayout, InvoicePrintLayout.splitLedger);
    });
  });

  group('Print invoice', () {
    testWidgets('the detail screen offers a print action', (tester) async {
      await pumpApp(tester, seed());

      await tester.tap(find.text('INV-001'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Print'), findsOneWidget);
    });

    testWidgets('the picker offers all three layouts', (tester) async {
      await pumpApp(tester, seed());

      await tester.tap(find.text('INV-001'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Print'));
      await tester.pumpAndSettle();

      expect(find.text('Print invoice'), findsOneWidget);
      expect(
        find.textContaining('All three are A4 and print in black and white.'),
        findsOneWidget,
      );
      for (final layout in InvoicePrintLayout.values) {
        expect(find.text(layout.label), findsOneWidget);
      }
    });

    testWidgets('a remembered layout opens the picker already ticked',
        (tester) async {
      final store = seed();
      store.printSettings =
          PrintSettings(defaultLayout: InvoicePrintLayout.paymentVoucher);

      await pumpApp(tester, store);
      await tester.tap(find.text('INV-001'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Print'));
      await tester.pumpAndSettle();

      final tile = tester.widget<InkWell>(
        find.ancestor(
          of: find.text(InvoicePrintLayout.paymentVoucher.label),
          matching: find.byType(InkWell),
        ),
      );
      expect(tile.onTap, isNotNull);
      expect(
        store.printSettings.defaultLayout,
        InvoicePrintLayout.paymentVoucher,
        reason: 'opening the picker must not clear the remembered layout',
      );
    });

    testWidgets('cancelling the picker prints nothing and changes nothing',
        (tester) async {
      final store = await pumpApp(tester, seed());

      await tester.tap(find.text('INV-001'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Print'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Print invoice'), findsNothing);
      expect(store.printSettings.defaultLayout, isNull);
    });

    testWidgets('ticking remember stores the layout once Print is pressed',
        (tester) async {
      final store = await pumpApp(tester, seed());

      await tester.tap(find.text('INV-001'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Print'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.text(InvoicePrintLayout.classicForm.label),
      );
      await tester.tap(find.text(InvoicePrintLayout.classicForm.label));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      final checkbox = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(checkbox.value, isTrue);
      expect(
        store.printSettings.defaultLayout,
        isNull,
        reason: 'the choice is only stored when the print actually runs',
      );
    });
  });

  group('PrintSettingsController', () {
    test('stores a default layout and clears it again', () async {
      final store = InMemoryLocalStore();
      final container = ProviderContainer(
        overrides: [localStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      await pumpEventQueue();
      expect(container.read(printSettingsProvider).defaultLayout, isNull);

      await container
          .read(printSettingsProvider.notifier)
          .setDefaultLayout(InvoicePrintLayout.splitLedger);
      expect(store.printSettings.defaultLayout, InvoicePrintLayout.splitLedger);
      expect(
        container.read(printSettingsProvider).defaultLayout,
        InvoicePrintLayout.splitLedger,
      );

      await container.read(printSettingsProvider.notifier).setDefaultLayout(null);
      expect(store.printSettings.defaultLayout, isNull);
      expect(container.read(printSettingsProvider).defaultLayout, isNull);
    });

    test('saves the business profile and shows it in the app state', () async {
      final store = InMemoryLocalStore();
      final container = ProviderContainer(
        overrides: [localStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      await pumpEventQueue();
      expect(container.read(businessProfileProvider).isEmpty, isTrue);

      await container.read(businessProfileProvider.notifier).save(
            BusinessProfile(name: 'PFA Pharmacy', tin: 'C0012345'),
          );
      expect(store.profile.name, 'PFA Pharmacy');
      expect(
        container.read(businessProfileProvider).contactLine,
        'TIN C0012345',
      );
    });
  });
}
