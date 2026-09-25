import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pfa_pharmacy_invoice_tracker/app.dart';
import 'package:pfa_pharmacy_invoice_tracker/data/app_database.dart';

import 'helpers.dart';

void main() {
  Future<InMemoryLocalStore> pumpApp(
    WidgetTester tester,
    InMemoryLocalStore store,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(store),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();
    return store;
  }

  group('InvoicesScreen', () {
    testWidgets('renders invoices with statuses and summary', (tester) async {
      final store = InMemoryLocalStore(
        suppliers: [
          supplier('s1', 'Pharma Co'),
          supplier('s2', 'Chem Co'),
        ],
        invoices: [
          invoice(
            id: 'i1',
            supplierId: 's1',
            invoiceNumber: 'INV-001',
            amountPesewas: 10000,
            dueDate: DateTime(2000, 1, 31),
          ),
          invoice(
            id: 'i2',
            supplierId: 's2',
            invoiceNumber: 'INV-002',
            amountPesewas: 5000,
            amountPaidPesewas: 5000,
            dueDate: DateTime(2030, 1, 31),
          ),
        ],
      );
      await pumpApp(tester, store);

      expect(find.text('Pharma Co'), findsOneWidget);
      expect(find.text('INV-002'), findsOneWidget);

      // Card label 'Overdue' + the overdue row's status cell.
      expect(find.text('Overdue'), findsNWidgets(2));
      // Column header 'Paid' + the paid row's status cell.
      expect(find.text('Paid'), findsNWidgets(2));

      // Total owing card, overdue card and row totals/balances.
      expect(find.text('₵100.00'), findsNWidgets(4));
      expect(find.text('₵50.00'), findsNWidgets(2));
      expect(find.text('₵0.00'), findsNWidgets(2));
      expect(find.text('1'), findsOneWidget); // Unpaid count.
    });

    testWidgets('filter by supplier shows only that supplier', (tester) async {
      final store = InMemoryLocalStore(
        suppliers: [
          supplier('s1', 'Pharma Co'),
          supplier('s2', 'Chem Co'),
        ],
        invoices: [
          invoice(
            id: 'i1',
            supplierId: 's1',
            invoiceNumber: 'INV-001',
            dueDate: DateTime(2000, 1, 31),
          ),
          invoice(
            id: 'i2',
            supplierId: 's2',
            invoiceNumber: 'INV-002',
            amountPaidPesewas: 5000,
            dueDate: DateTime(2030, 1, 31),
          ),
        ],
      );
      await pumpApp(tester, store);

      await tester.tap(find.text('All suppliers'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chem Co').last);
      await tester.pumpAndSettle();

      expect(find.text('INV-002'), findsOneWidget);
      expect(find.text('INV-001'), findsNothing);
    });

    testWidgets('adds an invoice through the form', (tester) async {
      final store = InMemoryLocalStore(
        suppliers: [supplier('s1', 'Pharma Co')],
      );
      await pumpApp(tester, store);

      await tester.tap(find.text('Invoice').last);
      await tester.pumpAndSettle();

      expect(find.text('New Invoice'), findsOneWidget);

      await tester.tap(find.text('Supplier'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Pharma Co');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pharma Co').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Invoice No'),
        'INV-010',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount (GH₵)'),
        '120',
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(store.invoices.single.invoiceNumber, 'INV-010');
      expect(store.invoices.single.supplierId, 's1');
      expect(store.invoices.single.amountPesewas, 12000);
      expect(find.text('INV-010'), findsOneWidget);
    });

    testWidgets('form blocks saving without a supplier', (tester) async {
      final store = InMemoryLocalStore(suppliers: [supplier('s1', 'Pharma Co')]);
      await pumpApp(tester, store);

      await tester.tap(find.text('Invoice').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Invoice No'),
        'INV-X',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount (GH₵)'),
        '10',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Select a supplier first.'), findsOneWidget);
      expect(store.invoices, isEmpty);
    });
  });
}