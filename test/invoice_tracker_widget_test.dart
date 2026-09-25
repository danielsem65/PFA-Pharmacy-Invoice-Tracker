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

      // Status words now render only inside the StatusBadge pill.
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('Paid'), findsOneWidget);

      // Header outstanding, overdue pill and row totals/balances.
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

      await tester.tap(find.text('New Invoice'));
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

    testWidgets('adds an invoice with product lines', (tester) async {
      final store = InMemoryLocalStore(
        suppliers: [supplier('s1', 'Pharma Co')],
      );
      await pumpApp(tester, store);

      await tester.tap(find.text('New Invoice'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Supplier'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Pharma Co');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pharma Co').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Invoice No'),
        'INV-020',
      );

      await tester.tap(find.text('Add item'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Product name'),
        'Panadol',
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'Boxes'), '2');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Pieces per box'),
        '24',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Price per box (GH₵)'),
        '55',
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = store.invoices.single;
      expect(saved.invoiceNumber, 'INV-020');
      expect(saved.lines, hasLength(1));
      expect(saved.lines.single.name, 'Panadol');
      expect(saved.lines.single.boxes, 2);
      expect(saved.lines.single.piecesPerBox, 24);
      expect(saved.lines.single.pricePerBoxPesewas, 5500);
      expect(saved.lines.single.pieceCount, 48);
      expect(saved.amountPesewas, 11000);
      expect(find.text('INV-020'), findsOneWidget);
    });

    testWidgets('form blocks saving without a supplier', (tester) async {
      final store = InMemoryLocalStore(suppliers: [supplier('s1', 'Pharma Co')]);
      await pumpApp(tester, store);

      await tester.tap(find.text('New Invoice'));
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

    testWidgets('bulk selects and deletes invoices', (tester) async {
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

      await tester.tap(find.byTooltip('Select invoices'));
      await tester.pumpAndSettle();

      // Selecting enters selection mode; the first invoice is pre-selected.
      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.text('INV-002'));
      await tester.pumpAndSettle();

      expect(find.text('2 selected'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete 2 invoices?'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(store.invoices, isEmpty);
      expect(find.text('No invoices yet'), findsOneWidget);
    });
  });
}
