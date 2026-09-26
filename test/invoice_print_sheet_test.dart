import 'package:flutter_test/flutter_test.dart';

import 'package:pfa_pharmacy_invoice_tracker/data/invoice_print_sheet.dart';
import 'package:pfa_pharmacy_invoice_tracker/models/business_profile.dart';
import 'package:pfa_pharmacy_invoice_tracker/models/supplier_invoice.dart';

import 'helpers.dart';

void main() {
  final printedOn = DateTime(2026, 3, 14, 9, 30);

  InvoicePrintSheet sheetFor(
    SupplierInvoice inv, {
    BusinessProfile? profile,
  }) {
    return buildInvoicePrintSheet(
      inv,
      supplier: supplier('s1', 'Pharma Co'),
      profile: profile ?? BusinessProfile(name: 'PFA Pharmacy'),
      printedOn: printedOn,
    );
  }

  group('buildInvoicePrintSheet', () {
    test('carries the business profile into the header', () {
      final sheet = sheetFor(
        invoice(),
        profile: BusinessProfile(
          name: 'PFA Pharmacy',
          address: '12 Oxford Street',
          phone: '030 123 4567',
          email: 'pfa@example.com',
          tin: 'C0012345',
        ),
      );

      expect(sheet.businessName, 'PFA Pharmacy');
      expect(
        sheet.contactLine,
        '12 Oxford Street · 030 123 4567 · pfa@example.com · TIN C0012345',
      );
    });

    test('leaves missing business details off the contact line', () {
      final sheet = sheetFor(
        invoice(),
        profile: BusinessProfile(name: 'PFA Pharmacy', phone: '030 123 4567'),
      );

      expect(sheet.contactLine, '030 123 4567');
      expect(sheet.contactLine, isNot(contains('·')));
    });

    test('a blank profile leaves no dangling separators', () {
      expect(BusinessProfile().contactLine, '');
    });

    test('names the supplier with its location and phone', () {
      final sheet = sheetFor(invoice());

      expect(sheet.supplierName, 'Pharma Co');
      expect(sheet.supplierLines, <String>['Accra', '555']);
    });

    test('falls back when the supplier record is missing', () {
      final sheet = buildInvoicePrintSheet(
        invoice(),
        profile: BusinessProfile(name: 'PFA Pharmacy'),
        printedOn: printedOn,
      );

      expect(sheet.supplierName, 'Unknown supplier');
      expect(sheet.supplierLines, isEmpty);
    });

    test('prints the invoice dates and status', () {
      final sheet = sheetFor(
        invoice(
          invoiceNumber: 'INV-42',
          invoiceDate: DateTime(2026, 1, 5),
          receivedDate: DateTime(2026, 1, 6),
          dueDate: DateTime(2026, 2, 5),
          reference: 'PO-9',
        ),
      );

      expect(sheet.invoiceNumber, 'INV-42');
      expect(sheet.invoiceDate, '05/01/2026');
      expect(sheet.receivedDate, '06/01/2026');
      expect(sheet.dueDate, '05/02/2026');
      expect(sheet.reference, 'PO-9');
      expect(sheet.hasReference, isTrue);
      expect(sheet.status, 'Overdue');
    });

    test('has no paid date until one is recorded', () {
      expect(sheetFor(invoice()).paidDate, isNull);

      final paid = sheetFor(
        invoice(amountPaidPesewas: 10000, paidDate: DateTime(2026, 1, 15)),
      );
      expect(paid.paidDate, '15/01/2026');
    });

    test('keeps the money block identical to what the app shows', () {
      final inv = invoice(
        amountPesewas: 100000,
        taxRatePercent: 15,
        amountPaidPesewas: 40000,
      );
      final sheet = sheetFor(inv);

      expect(sheet.totals.subtotal, inv.amountPesewas);
      expect(sheet.totals.tax, inv.taxPesewas);
      expect(sheet.totals.total, inv.totalPesewas);
      expect(sheet.totals.paid, inv.amountPaidPesewas);
      expect(sheet.totals.balance, inv.balancePesewas);
      expect(sheet.totals.total, 115000);
      expect(sheet.totals.balance, 75000);
      expect(sheet.totals.isSettled, isFalse);
      expect(sheet.totals.balanceLabel, 'Balance due');
      expect(sheet.totals.hasTax, isTrue);
    });

    test('calls a cleared invoice settled', () {
      final sheet = sheetFor(
        invoice(amountPesewas: 10000, amountPaidPesewas: 10000),
      );

      expect(sheet.totals.isSettled, isTrue);
      expect(sheet.totals.balanceLabel, 'Balance settled');
    });

    test('omits a zero tax line and keeps a whole-number rate tidy', () {
      final sheet = sheetFor(invoice(taxRatePercent: 0));
      expect(sheet.totals.hasTax, isFalse);
      expect(sheet.totals.taxLabel, 'VAT (0%)');

      final taxed = sheetFor(invoice(taxRatePercent: 15));
      expect(taxed.totals.taxLabel, 'VAT (15%)');
    });

    test('keeps a decimal tax rate as written', () {
      expect(sheetFor(invoice(taxRatePercent: 7.5)).totals.taxLabel, 'VAT (7.5%)');
    });

    test('spells the total out in words', () {
      final sheet = sheetFor(invoice(amountPesewas: 123450));

      expect(
        sheet.totals.amountInWords,
        'One Thousand Two Hundred And Thirty-Four Ghana Cedis And Fifty '
        'Pesewas Only',
      );
    });

    test('lists every line with its quantity and totals', () {
      final sheet = sheetFor(
        invoice(
          amountPesewas: 4500,
          lines: <InvoiceLine>[
            InvoiceLine(
              name: 'Paracetamol 500mg',
              boxes: 2,
              piecesPerBox: 20,
              pricePerBoxPesewas: 1000,
            ),
            InvoiceLine(
              name: 'Vitamin C',
              boxes: 1,
              piecesPerBox: 10,
              pricePerBoxPesewas: 2500,
            ),
          ],
        ),
      );

      expect(sheet.hasLines, isTrue);
      expect(sheet.lines, hasLength(2));
      expect(sheet.lines.first.name, 'Paracetamol 500mg');
      expect(sheet.lines.first.boxes, 2);
      expect(sheet.lines.first.piecesPerBox, 20);
      expect(sheet.lines.first.pricePerBox, 1000);
      expect(sheet.lines.first.lineTotal, 2000);
      expect(sheet.lines.first.quantityLabel, '2 box × 20');
      expect(sheet.lines.last.lineTotal, 2500);
      expect(sheet.totals.subtotalLabel, 'Subtotal');
    });

    test('calls a line-less invoice an amount, not a subtotal', () {
      final sheet = sheetFor(invoice(amountPesewas: 7500));

      expect(sheet.hasLines, isFalse);
      expect(sheet.lines, isEmpty);
      expect(sheet.totals.subtotalLabel, 'Amount');
    });

    test('only reports reference, description and notes when they exist', () {
      final bare = sheetFor(invoice());
      expect(bare.hasReference, isFalse);
      expect(bare.hasDescription, isFalse);
      expect(bare.hasNotes, isFalse);
      expect(bare.hasPaymentMethod, isTrue);

      final full = sheetFor(
        invoice(reference: 'PO-1', description: 'March delivery', notes: 'Check seals'),
      );
      expect(full.hasReference, isTrue);
      expect(full.description, 'March delivery');
      expect(full.notes, 'Check seals');
    });
  });

  group('BusinessProfile', () {
    test('round trips through JSON', () {
      final profile = BusinessProfile(
        name: 'PFA Pharmacy',
        address: '12 Oxford Street',
        phone: '030 123 4567',
        email: 'pfa@example.com',
        tin: 'C0012345',
      );

      expect(BusinessProfile.fromJson(profile.toJson()).name, 'PFA Pharmacy');
      expect(BusinessProfile.fromJson(profile.toJson()).tin, 'C0012345');
    });

    test('survives a JSON record with missing fields', () {
      final profile = BusinessProfile.fromJson(<String, dynamic>{});

      expect(profile.isEmpty, isTrue);
      expect(profile.name, '');
    });
  });
}
