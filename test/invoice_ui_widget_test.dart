import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pfa_pharmacy_invoice_tracker/app.dart';
import 'package:pfa_pharmacy_invoice_tracker/data/app_database.dart';
import 'package:pfa_pharmacy_invoice_tracker/models/supplier_invoice.dart';
import 'package:pfa_pharmacy_invoice_tracker/widgets/app_sidebar.dart';
import 'package:pfa_pharmacy_invoice_tracker/widgets/desktop_form.dart';
import 'package:pfa_pharmacy_invoice_tracker/widgets/stat_card.dart';

import 'helpers.dart';

/// Covers the invoice screen work: the detail page matching the list styling,
/// payments belonging to the Payments page only, the narrower Record Payment
/// form, and the item heading that used to break 'ITEM' across two lines.
void main() {
  Future<InMemoryLocalStore> pumpApp(
    WidgetTester tester,
    InMemoryLocalStore store, {
    Size size = const Size(1400, 1000),
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

  Future<void> openForm(WidgetTester tester) async {
    await tester.tap(find.text('New Invoice'));
    await tester.pumpAndSettle();
  }

  group('Invoice detail', () {
    testWidgets('shows the figures, panels and print action', (tester) async {
      final store = InMemoryLocalStore(
        suppliers: [supplier('s1', 'Pharma Co')],
        invoices: [
          invoice(
            id: 'i1',
            supplierId: 's1',
            invoiceNumber: 'INV-001',
            amountPesewas: 20000,
            amountPaidPesewas: 5000,
            paidDate: DateTime(2000, 1, 15),
            dueDate: DateTime(2030, 1, 31),
            receipts: const ['2000_01_15_panorama.png'],
            lines: [
              InvoiceLine(name: 'Panadol', boxes: 2, pricePerBoxPesewas: 1000),
            ],
          ),
        ],
      );
      await pumpApp(tester, store);

      await tester.tap(find.text('INV-001'));
      await tester.pumpAndSettle();

      // The four money figures lead the page.
      final labels = tester
          .widgetList<StatCard>(find.byType(StatCard))
          .map((c) => c.label)
          .toList();
      expect(labels, containsAll(<String>['Total', 'Paid', 'Balance', 'Due']));

      // Then the panels.
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Amounts'), findsOneWidget);
      expect(find.text('Amount in words'), findsOneWidget);
      expect(find.text('Items (1)'), findsOneWidget);
      expect(find.text('Receipts (1)'), findsOneWidget);
      expect(find.text('Panadol'), findsOneWidget);

      // One print affordance, and it is the one the print tests look for.
      expect(find.byTooltip('Print'), findsOneWidget);
      expect(find.byKey(const Key('print-invoice')), findsOneWidget);
    });

    testWidgets('the back button returns to the list', (tester) async {
      final store = InMemoryLocalStore(
        suppliers: [supplier('s1', 'Pharma Co')],
        invoices: [invoice(id: 'i1', supplierId: 's1')],
      );
      await pumpApp(tester, store);

      await tester.tap(find.text('INV-1'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('invoice-back')), findsOneWidget);

      await tester.tap(find.byKey(const Key('invoice-back')));
      await tester.pumpAndSettle();

      expect(find.text('New Invoice'), findsOneWidget);
      expect(find.byKey(const Key('invoice-back')), findsNothing);
    });
  });

  group('Invoice form payments', () {
    testWidgets('offers no paid amount, paid date or payment method', (
      tester,
    ) async {
      final store = InMemoryLocalStore(
        suppliers: [supplier('s1', 'Pharma Co')],
      );
      await pumpApp(tester, store);
      await openForm(tester);

      expect(find.text('Paid (GH₵)'), findsNothing);
      expect(find.text('Paid Date'), findsNothing);
      expect(find.text('Payment method'), findsNothing);

      // The paid row survives in the totals, but only as a reading of what the
      // Payments page has already recorded.
      expect(find.text('Paid'), findsOneWidget);
      expect(
        find.text(
          'Record a payment on the Payments page once this invoice is saved.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('editing a paid invoice keeps the payment intact', (
      tester,
    ) async {
      final paidOn = DateTime(2000, 1, 15);
      final store = InMemoryLocalStore(
        suppliers: [supplier('s1', 'Pharma Co')],
        invoices: [
          invoice(
            id: 'i1',
            supplierId: 's1',
            invoiceNumber: 'INV-001',
            amountPesewas: 20000,
            amountPaidPesewas: 7500,
            paidDate: paidOn,
            paymentMethod: 'Bank Pay',
          ),
        ],
      );
      await pumpApp(tester, store);

      await tester.tap(find.text('INV-001'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();

      // The ledger figure is shown, never offered for editing.
      expect(find.text('Paid (GH₵)'), findsNothing);
      expect(find.text('₵75.00'), findsOneWidget);
      expect(
        find.text('Payments are recorded on the Payments page.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Notes'),
        'Checked against the delivery note',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = store.invoices.single;
      expect(saved.amountPaidPesewas, 7500);
      expect(saved.paidDate, paidOn);
      expect(saved.paymentMethod, 'Bank Pay');
      expect(saved.notes, 'Checked against the delivery note');
    });
  });

  group('Invoice form item headings', () {
    testWidgets('ITEM stays on one line', (tester) async {
      final store = InMemoryLocalStore(
        suppliers: [supplier('s1', 'Pharma Co')],
      );
      // The item lines are laid out as a table — headings and all — only inside
      // this width band: wide enough for the columns, narrow enough that the
      // form has not yet split into a main column and a side column.
      await pumpApp(tester, store, size: const Size(1000, 1400));
      await openForm(tester);

      final add = find.text('Add item');
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();

      final heading = tester.widget<Text>(find.text('ITEM'));
      expect(heading.maxLines, 1);
      expect(heading.softWrap, isFalse);

      // A wrapped heading is roughly twice as tall as a single line.
      expect(tester.getSize(find.text('ITEM')).height, lessThan(22));
      expect(tester.takeException(), isNull);
    });
  });

  group('Record payment form', () {
    testWidgets('is centred in a comfortable reading width', (tester) async {
      final store = InMemoryLocalStore(
        suppliers: [supplier('s1', 'Pharma Co')],
        invoices: [
          invoice(id: 'i1', supplierId: 's1', dueDate: DateTime(2030, 1, 31)),
        ],
      );
      await pumpApp(tester, store);

      await tester.tap(
        find.descendant(
          of: find.byType(AppSidebar),
          matching: find.text('Payments'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('new-payment')));
      await tester.pumpAndSettle();

      // The AppBar is gone, so the heading carries the way back.
      expect(find.byKey(const Key('payment-back')), findsOneWidget);

      // Held to a reading width rather than stretched across the window, and
      // centred in whatever space it is given. The wrapper fills the window; the
      // first ConstrainedBox inside it is the one that does the holding, the
      // rest belonging to the fields further down.
      final wrapper = find.byType(ReadingWidth);
      final block = find
          .descendant(of: wrapper, matching: find.byType(ConstrainedBox))
          .first;
      expect(tester.getSize(block).width, 720);
      expect(
        tester.getRect(block).center.dx,
        closeTo(tester.getRect(wrapper).center.dx, 1),
      );
      expect(
        tester.getRect(find.byKey(const Key('payment-amount'))).width,
        lessThanOrEqualTo(720),
      );

      // Still a working form.
      expect(find.byKey(const Key('payment-supplier')), findsOneWidget);
      expect(find.byKey(const Key('save-form')), findsOneWidget);
    });
  });

  group('Creating a supplier from the invoice form', () {
    // The text field inside the supplier search, which is where the offer to
    // create a missing supplier appears.
    final Finder supplierSearch = find.descendant(
      of: find.byType(SearchAnchor),
      matching: find.byType(TextField),
    );
    final Finder invoiceNo = find.widgetWithText(TextFormField, 'Invoice No');

    testWidgets('keeps the half-finished invoice on screen', (tester) async {
      final store = InMemoryLocalStore(suppliers: [supplier('s1', 'Pharma Co')]);
      await pumpApp(tester, store);
      await openForm(tester);

      // Something already typed on the form, which is the whole point: losing
      // this is what made the flow unusable.
      await tester.enterText(invoiceNo, 'INV-900');
      await tester.pumpAndSettle();

      // No supplier matches, so the search offers to make one.
      await tester.enterText(supplierSearch, 'Emerald');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create “Emerald”'));
      await tester.pumpAndSettle();

      expect(find.text('New supplier'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Phone (optional)'),
        '024 555 0199',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      // Only the dialog closes.
      expect(find.text('New supplier'), findsNothing);

      // The supplier was still created, and is now the one on the invoice.
      expect(store.suppliers.map((s) => s.name), contains('Emerald'));
      expect(
        store.suppliers.firstWhere((s) => s.name == 'Emerald').phone,
        '024 555 0199',
      );

      // And the form is still the form, with the work on it intact.
      expect(find.text('New Invoice'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(invoiceNo).controller!.text,
        'INV-900',
      );
    });

    testWidgets('cancelling the dialog changes nothing at all', (tester) async {
      final store = InMemoryLocalStore(suppliers: [supplier('s1', 'Pharma Co')]);
      await pumpApp(tester, store);
      await openForm(tester);
      await tester.enterText(invoiceNo, 'INV-900');
      await tester.pumpAndSettle();

      await tester.enterText(supplierSearch, 'Emerald');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create “Emerald”'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('New supplier'), findsNothing);
      expect(store.suppliers.map((s) => s.name), isNot(contains('Emerald')));
      expect(find.text('New Invoice'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(invoiceNo).controller!.text,
        'INV-900',
      );
    });
  });
}
