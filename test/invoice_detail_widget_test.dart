import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pfa_pharmacy_invoice_tracker/app.dart';
import 'package:pfa_pharmacy_invoice_tracker/data/app_database.dart';
import 'package:pfa_pharmacy_invoice_tracker/models/supplier_invoice.dart';
import 'package:pfa_pharmacy_invoice_tracker/widgets/app_sidebar.dart';

import 'helpers.dart';

void main() {
  // The viewer is a long page, so the surface is given room to lay out every
  // card rather than scrolling to go looking for them.
  Future<void> openInvoice(WidgetTester tester, SupplierInvoice invoice) async {
    final store = InMemoryLocalStore(
      suppliers: [supplier('s1', 'TonyKay Pharmacy')],
      invoices: <SupplierInvoice>[invoice],
    );
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStoreProvider.overrideWithValue(store)],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();
    final nav = tester.getRect(
      find.descendant(
        of: find.byType(AppSidebar),
        matching: find.text('Invoices'),
      ),
    );
    await tester.tapAt(Offset(nav.left - 26, nav.center.dy));
    await tester.pumpAndSettle();
    await tester.tap(find.text(invoice.invoiceNumber));
    await tester.pumpAndSettle();
  }

  // 1139.00 plus 15% tax is 1309.85; 900.00 paid leaves 409.85 owing.
  SupplierInvoice partPaid() => invoice(
        id: 'i1',
        supplierId: 's1',
        invoiceNumber: 'INV-0148',
        invoiceDate: DateTime(2026, 3, 12),
        receivedDate: DateTime(2026, 3, 14),
        dueDate: DateTime.now().add(const Duration(days: 15)),
        amountPesewas: 113900,
        taxRatePercent: 15,
        amountPaidPesewas: 90000,
        paidDate: DateTime(2026, 3, 18),
        reference: 'PO-2291',
        description: 'March replenishment',
        paymentMethod: 'Bank Pay',
        notes: 'Deliver before closing on the 14th.',
        receipts: <String>['r_receipt-2291.jpg'],
        lines: <InvoiceLine>[
          InvoiceLine(
            name: 'Artemether 120mg',
            boxes: 2,
            piecesPerBox: 12,
            pricePerBoxPesewas: 3850,
          ),
          InvoiceLine(
            name: 'ORS Sachet',
            boxes: 10,
            piecesPerBox: 25,
            pricePerBoxPesewas: 1800,
          ),
        ],
      );

  group('Invoice detail viewer', () {
    testWidgets('leads with the four figures', (tester) async {
      await openInvoice(tester, partPaid());

      // The captions carry what the big numbers cannot hold, so they are worth
      // reading back whole rather than in pieces.
      final captions = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .toList();
      final why = 'captions on the page: $captions';

      expect(captions, contains('12 boxes · 274 pieces'), reason: why);
      expect(captions, contains('due in 15 days'), reason: why);
      expect(
        captions.any((s) => RegExp(r'^\d+% settled · Bank Pay$').hasMatch(s)),
        isTrue,
        reason: why,
      );
      expect(find.text('Partially Paid'), findsOneWidget);
      // The balance is on a tile and repeated in words, because money owed is
      // the one figure worth saying twice.
      expect(find.text('BALANCE'), findsNWidgets(2));
    });

    testWidgets('keeps the paperwork on the dark panel', (tester) async {
      await openInvoice(tester, partPaid());

      expect(find.textContaining('Invoice date'), findsOneWidget);
      expect(find.textContaining('Received'), findsOneWidget);
      expect(find.textContaining('Due'), findsOneWidget);
      expect(find.textContaining('Paid on'), findsOneWidget);
      expect(find.textContaining('Ref PO-2291'), findsOneWidget);
    });

    testWidgets('keeps the items, the words and the receipts', (tester) async {
      await openInvoice(tester, partPaid());

      expect(find.text('Items (2)'), findsOneWidget);
      expect(find.text('Artemether 120mg'), findsOneWidget);
      expect(find.text('AMOUNT IN WORDS'), findsOneWidget);
      expect(find.text('Receipts (1)'), findsOneWidget);
      expect(find.text('receipt-2291.jpg'), findsOneWidget);
      expect(find.text('Deliver before closing on the 14th.'), findsOneWidget);
    });

    testWidgets('a settled invoice shows the total, not a zero balance',
        (tester) async {
      await openInvoice(
        tester,
        invoice(
          id: 'i2',
          invoiceNumber: 'INV-0149',
          amountPesewas: 50000,
          amountPaidPesewas: 50000,
          paidDate: DateTime(2026, 3, 18),
        ),
      );

      expect(find.text('Paid'), findsOneWidget);
      expect(find.textContaining('settled in full'), findsOneWidget);
      // Only the tile says balance now; the words card leaves the row out
      // rather than spell out a round zero.
      expect(find.text('BALANCE'), findsOneWidget);
    });
  });
}
