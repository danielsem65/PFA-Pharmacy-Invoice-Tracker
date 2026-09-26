import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pfa_pharmacy_invoice_tracker/app.dart';
import 'package:pfa_pharmacy_invoice_tracker/data/app_database.dart';
import 'package:pfa_pharmacy_invoice_tracker/models/payment.dart';
import 'package:pfa_pharmacy_invoice_tracker/models/supplier_invoice.dart';
import 'package:pfa_pharmacy_invoice_tracker/widgets/app_sidebar.dart';

import 'helpers.dart';

void main() {
  Future<InMemoryLocalStore> pumpApp(
    WidgetTester tester,
    InMemoryLocalStore store,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
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

  /// One invoice settled by a record, three open for Pharma Co, one for Chem Co,
  /// and one Chem Co invoice already past its due date. The paid amount on
  /// INV-001 matches its record, so the ledger has nothing left to seed.
  InMemoryLocalStore ledger() => InMemoryLocalStore(
        suppliers: [supplier('s1', 'Pharma Co'), supplier('s2', 'Chem Co')],
        invoices: <SupplierInvoice>[
          invoice(
            id: 'i1',
            supplierId: 's1',
            invoiceNumber: 'INV-001',
            amountPesewas: 10000,
            amountPaidPesewas: 10000,
            paidDate: DateTime(2026, 1, 15),
            paymentMethod: 'Bank Pay',
            dueDate: DateTime(2000, 1, 31),
          ),
          invoice(
            id: 'i2',
            supplierId: 's1',
            invoiceNumber: 'INV-002',
            amountPesewas: 20000,
            dueDate: DateTime(2030, 1, 31),
          ),
          invoice(
            id: 'i3',
            supplierId: 's1',
            invoiceNumber: 'INV-003',
            amountPesewas: 5000,
            dueDate: DateTime(2030, 2, 28),
          ),
          invoice(
            id: 'i4',
            supplierId: 's2',
            invoiceNumber: 'INV-004',
            amountPesewas: 5000,
            dueDate: DateTime(2030, 1, 31),
          ),
          invoice(
            id: 'i5',
            supplierId: 's2',
            invoiceNumber: 'INV-005',
            amountPesewas: 5000,
            dueDate: DateTime(2000, 1, 31),
          ),
        ],
        payments: <Payment>[
          Payment(
            date: DateTime(2026, 1, 15),
            method: 'Bank Pay',
            reference: 'TELLER-1',
            allocations: const <PaymentAllocation>[
              PaymentAllocation(invoiceId: 'i1', amountPesewas: 10000),
            ],
          ),
        ],
      );

  Future<void> openPayments(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(AppSidebar),
        matching: find.text('Payments'),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openForm(WidgetTester tester) async {
    await openPayments(tester);
    await tester.tap(find.byKey(const Key('new-payment')));
    await tester.pumpAndSettle();
  }

  Future<void> pickSupplier(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(const Key('payment-supplier')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  /// The invoice list sits below the fold on a short window, so each control is
  /// brought into view before it is tapped.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('PaymentsScreen', () {
    testWidgets('opens from the sidebar and lists what was paid',
        (tester) async {
      await pumpApp(tester, ledger());
      await openPayments(tester);

      expect(find.text('1 payment recorded'), findsOneWidget);
      expect(find.text('Pharma Co'), findsOneWidget);
      expect(find.text('INV-001'), findsOneWidget);
      expect(find.text('Bank Pay'), findsOneWidget);
      expect(find.text('TELLER-1'), findsOneWidget);
    });

    testWidgets('the totals add up across every invoice', (tester) async {
      await pumpApp(tester, ledger());
      await openPayments(tester);

      // Paid 100.00. Owed 200.00 + 50.00 + 50.00 + 50.00 = 350.00. Of that,
      // INV-005 is past its due date, so 50.00 is overdue. Nothing was paid
      // this month. The 100.00 shows twice: the record, and the paid total.
      expect(find.text('TOTAL PAID'), findsOneWidget);
      expect(find.text('₵100.00'), findsNWidgets(2));
      expect(find.text('STILL OWED'), findsOneWidget);
      expect(find.text('₵350.00'), findsOneWidget);
      expect(find.text('OVERDUE'), findsOneWidget);
      expect(find.text('₵50.00'), findsOneWidget);
      expect(find.text('PAID THIS MONTH'), findsOneWidget);
      expect(find.text('₵0.00'), findsOneWidget);
    });

    testWidgets('searching for an unpaid invoice finds no payment',
        (tester) async {
      await pumpApp(tester, ledger());
      await openPayments(tester);

      await tester.enterText(find.byType(TextField).first, 'INV-004');
      await tester.pumpAndSettle();

      expect(find.text('No payments match'), findsOneWidget);
    });

    testWidgets('a supplier with no payments of their own is left out',
        (tester) async {
      await pumpApp(tester, ledger());
      await openPayments(tester);

      await tester.tap(find.byKey(const Key('payments-supplier-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chem Co').last);
      await tester.pumpAndSettle();

      expect(find.text('No payments match'), findsOneWidget);
    });
  });

  group('recording a payment', () {
    testWidgets('one payment settles two invoices and updates both balances',
        (tester) async {
      final store = ledger();
      await pumpApp(tester, store);
      await openForm(tester);
      await pickSupplier(tester, 'Pharma Co');

      // INV-001 is settled already, so only the two open ones are offered.
      expect(find.byKey(const Key('pay-invoice-i1')), findsNothing);
      expect(find.byKey(const Key('pay-invoice-i2')), findsOneWidget);
      expect(find.byKey(const Key('pay-invoice-i3')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('payment-amount')), '150.00');
      await tester.pumpAndSettle();

      await tapVisible(tester, find.byKey(const Key('pay-invoice-i2')));
      await tapVisible(tester, find.byKey(const Key('pay-invoice-i3')));
      await tapVisible(tester, find.byKey(const Key('split-evenly')));

      // 150.00 across two invoices: 100.00 to the 200.00 one, then the 50.00
      // one takes the rest, so nothing is left over.
      String shownFor(String id) =>
          tester.widget<TextField>(find.byKey(Key('pay-amount-$id'))).controller!.text;
      expect(shownFor('i2'), '100.00');
      expect(shownFor('i3'), '50.00');
      expect(
        find.text('Every pesewa of the payment has a home.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('save-form')));
      await tester.pumpAndSettle();

      expect(store.payments, hasLength(2));
      final added = store.payments.first;
      expect(added.amountPesewas, 15000);
      expect(added.invoiceIds, <String>{'i2', 'i3'});

      final i2 = store.invoices.firstWhere((i) => i.id == 'i2');
      final i3 = store.invoices.firstWhere((i) => i.id == 'i3');
      expect(i2.amountPaidPesewas, 10000);
      expect(i2.balancePesewas, 10000);
      expect(i3.amountPaidPesewas, 5000);
      expect(i3.balancePesewas, 0);

      // Back on the ledger, with both records on it. The 150.00 shows twice:
      // the new record, and the paid-this-month figure it lands in.
      expect(find.text('2 payments recorded'), findsOneWidget);
      expect(find.text('INV-002, INV-003'), findsOneWidget);
      expect(find.text('₵150.00'), findsNWidgets(2));
    });

    testWidgets('a payment with nothing ticked is refused', (tester) async {
      final store = ledger();
      await pumpApp(tester, store);
      await openForm(tester);
      await pickSupplier(tester, 'Pharma Co');

      await tester.enterText(find.byKey(const Key('payment-amount')), '50.00');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-form')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('payment-error')), findsOneWidget);
      expect(store.payments, hasLength(1));
    });

    testWidgets('money left unhanded out is refused', (tester) async {
      final store = ledger();
      await pumpApp(tester, store);
      await openForm(tester);
      await pickSupplier(tester, 'Pharma Co');

      await tester.enterText(find.byKey(const Key('payment-amount')), '500.00');
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('pay-invoice-i2')));

      await tester.tap(find.byKey(const Key('save-form')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('payment-error')), findsOneWidget);
      expect(store.payments, hasLength(1));
      expect(
        store.invoices.firstWhere((i) => i.id == 'i2').amountPaidPesewas,
        0,
      );
    });

    testWidgets('a supplier with nothing outstanding says so',
        (tester) async {
      final store = InMemoryLocalStore(
        suppliers: [supplier('s1', 'Pharma Co')],
        invoices: <SupplierInvoice>[
          invoice(
            id: 'i1',
            supplierId: 's1',
            invoiceNumber: 'INV-001',
            amountPesewas: 10000,
            amountPaidPesewas: 10000,
            paidDate: DateTime(2026, 1, 20),
            dueDate: DateTime(2000, 1, 31),
          ),
        ],
      );
      await pumpApp(tester, store);
      await openForm(tester);
      await pickSupplier(tester, 'Pharma Co');

      expect(
        find.text('This supplier has nothing outstanding.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('pay-invoice-i1')), findsNothing);
    });

    testWidgets('deleting a record hands the money back to the invoices',
        (tester) async {
      final store = ledger();
      await pumpApp(tester, store);
      await openPayments(tester);

      await tester.tap(find.text('INV-001'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this payment?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(store.payments, isEmpty);
      final i1 = store.invoices.firstWhere((i) => i.id == 'i1');
      expect(i1.amountPaidPesewas, 0);
      expect(i1.balancePesewas, 10000);
      expect(find.text('No payments yet'), findsOneWidget);
    });
  });
}
