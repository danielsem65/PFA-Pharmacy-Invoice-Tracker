import 'package:flutter_test/flutter_test.dart';

import 'package:pfa_pharmacy_invoice_tracker/models/supplier.dart';
import 'package:pfa_pharmacy_invoice_tracker/models/supplier_invoice.dart';

import 'helpers.dart';

void main() {
  group('SupplierInvoice', () {
    test('toJson/fromJson round trip', () {
      final original = invoice(
        id: 'i9',
        supplierId: 's2',
        invoiceNumber: 'PH-009',
        invoiceDate: DateTime(2001, 5, 3),
        receivedDate: DateTime(2001, 5, 5),
        dueDate: DateTime(2001, 6, 3),
        amountPesewas: 125050,
        taxRatePercent: 15,
        amountPaidPesewas: 50000,
        paidDate: DateTime(2001, 5, 20),
        reference: 'PO-77',
        description: 'Amoxicillin 500mg x 10',
        paymentMethod: 'MoMo',
        receipts: const ['r1', 'r2'],
      );
      final restored = SupplierInvoice.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.invoiceNumber, 'PH-009');
      expect(restored.dueDate, original.dueDate);
      expect(restored.taxRatePercent, 15);
      expect(restored.receipts, ['r1', 'r2']);
    });

    test('computed money fields', () {
      final inv = invoice(amountPesewas: 10000, taxRatePercent: 10);
      expect(inv.taxPesewas, 1000);
      expect(inv.totalPesewas, 11000);
      expect(inv.balancePesewas, 11000);
      expect(inv.owesMoney, isTrue);
    });

    test('statusAt returns paid when fully settled', () {
      final inv = invoice(
        amountPesewas: 10000,
        amountPaidPesewas: 11000,
        dueDate: DateTime(2000, 1, 31),
      );
      expect(inv.statusAt(DateTime(2026, 9, 1)), InvoiceStatus.paid);
    });

    test('statusAt returns overdue when owed and past due', () {
      final inv = invoice(
        amountPesewas: 10000,
        dueDate: DateTime(2000, 1, 31),
      );
      expect(inv.statusAt(DateTime(2026, 9, 1)), InvoiceStatus.overdue);
    });

    test('statusAt returns open when owed and not yet due', () {
      final inv = invoice(
        amountPesewas: 10000,
        dueDate: DateTime(2030, 1, 31),
      );
      expect(inv.statusAt(DateTime(2026, 9, 1)), InvoiceStatus.open);
    });

    test('statusAt returns partially paid when partly settled and not due', () {
      final inv = invoice(
        amountPesewas: 10000,
        amountPaidPesewas: 2000,
        dueDate: DateTime(2030, 1, 31),
      );
      expect(
        inv.statusAt(DateTime(2026, 9, 1)),
        InvoiceStatus.partiallyPaid,
      );
    });

    test('copyWith clears paid date when requested', () {
      final inv = invoice(
        amountPesewas: 10000,
        amountPaidPesewas: 10000,
        paidDate: DateTime(2001, 1, 1),
      );
      final cleared = inv.copyWith(clearPaidDate: true);
      expect(cleared.paidDate, isNull);
      expect(cleared.amountPaidPesewas, 10000);
      final kept = inv.copyWith(paidDate: null);
      expect(kept.paidDate, DateTime(2001, 1, 1));
    });
  });

  group('Supplier', () {
    test('toJson/fromJson round trip with defaults', () {
      final s = Supplier(
        id: 's1',
        name: 'Pharma Co',
      );
      final restored = Supplier.fromJson(s.toJson());
      expect(restored.phone, '');
      expect(restored.location, '');
      expect(restored.name, 'Pharma Co');
    });

    test('create generates a unique id', () {
      final a = Supplier.create('A');
      final b = Supplier.create('A');
      expect(a.id, isNot(b.id));
    });
  });
}