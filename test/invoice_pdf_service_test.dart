import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:pfa_pharmacy_invoice_tracker/data/invoice_pdf_service.dart';
import 'package:pfa_pharmacy_invoice_tracker/data/invoice_print_sheet.dart';
import 'package:pfa_pharmacy_invoice_tracker/models/business_profile.dart';
import 'package:pfa_pharmacy_invoice_tracker/models/print_settings.dart';
import 'package:pfa_pharmacy_invoice_tracker/models/supplier_invoice.dart';

import 'helpers.dart';

void main() {
  final printedOn = DateTime(2026, 3, 14, 9, 30);
  final profile = BusinessProfile(
    name: 'PFA Pharmacy',
    address: '12 Oxford Street',
    phone: '030 123 4567',
    tin: 'C0012345',
  );

  List<InvoiceLine> lines(int count) => <InvoiceLine>[
        for (var i = 0; i < count; i++)
          InvoiceLine(
            name: 'Medicine number $i',
            boxes: 2,
            piecesPerBox: 20,
            pricePerBoxPesewas: 1000,
          ),
      ];

  Future<Uint8List> build({
    SupplierInvoice? inv,
    InvoicePrintLayout layout = InvoicePrintLayout.classicForm,
    bool withSupplier = true,
    bool withProfile = true,
  }) {
    return buildInvoicePdf(
      inv ?? invoice(),
      supplier: withSupplier ? supplier('s1', 'Pharma Co') : null,
      profile: withProfile ? profile : null,
      layout: layout,
      printedOn: printedOn,
    );
  }

  test('a PDF starts with the PDF header', () async {
    final bytes = await build();

    expect(bytes.length, greaterThan(500));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('every layout builds a real PDF', () async {
    for (final layout in InvoicePrintLayout.values) {
      final bytes = await build(
        inv: invoice(
          amountPesewas: 4500,
          taxRatePercent: 15,
          amountPaidPesewas: 1000,
          lines: lines(3),
        ),
        layout: layout,
      );

      expect(bytes, isNotEmpty, reason: '${layout.label} produced no bytes');
      expect(
        String.fromCharCodes(bytes.take(5)),
        '%PDF-',
        reason: '${layout.label} is not a PDF',
      );
    }
  });

  test('an invoice with no lines still prints', () async {
    for (final layout in InvoicePrintLayout.values) {
      final bytes = await build(
        inv: invoice(amountPesewas: 7500),
        layout: layout,
      );

      expect(bytes.length, greaterThan(500), reason: layout.label);
    }
  });

  test('a fully paid invoice still prints', () async {
    for (final layout in InvoicePrintLayout.values) {
      final bytes = await build(
        inv: invoice(
          amountPesewas: 10000,
          amountPaidPesewas: 10000,
          paidDate: DateTime(2026, 1, 15),
        ),
        layout: layout,
      );

      expect(bytes.length, greaterThan(500), reason: layout.label);
    }
  });

  test('a missing supplier or business profile still prints', () async {
    for (final layout in InvoicePrintLayout.values) {
      final bytes = await build(
        inv: invoice(lines: lines(2)),
        layout: layout,
        withSupplier: false,
        withProfile: false,
      );

      expect(bytes.length, greaterThan(500), reason: layout.label);
    }
  });

  test('a long item list prints in every layout', () async {
    for (final layout in InvoicePrintLayout.values) {
      final bytes = await build(
        inv: invoice(amountPesewas: 60 * 2000, lines: lines(60)),
        layout: layout,
      );

      expect(bytes.length, greaterThan(500), reason: layout.label);
    }
  });

  test('a very long product name does not break the page', () async {
    final bytes = await build(
      inv: invoice(
        amountPesewas: 2000,
        lines: <InvoiceLine>[
          InvoiceLine(
            name: 'Amoxicillin 500mg Capsules BP 500mg x 1000 Dispensary Pack '
                'with Child-Resistant Cap and Printed Expiry Band',
            boxes: 1,
            piecesPerBox: 1000,
            pricePerBoxPesewas: 2000,
          ),
        ],
      ),
      layout: InvoicePrintLayout.splitLedger,
    );

    expect(bytes.length, greaterThan(500));
  });

  test('notes and a reference are printed without breaking the layout',
      () async {
    final bytes = await build(
      inv: invoice(
        reference: 'PO-9988',
        description: 'March delivery',
        notes: 'Check the seals on every carton before signing.',
        lines: lines(2),
      ),
    );

    expect(bytes.length, greaterThan(500));
  });

  test('the classic table gives every value column a title', () {
    final table = classicItemsTable(
      buildInvoicePrintSheet(
        invoice(amountPesewas: 6000, lines: lines(2)),
        supplier: supplier('s1', 'Pharma Co'),
        profile: profile,
        printedOn: printedOn,
      ),
      PrintFonts.instance,
    );

    expect(table, isA<pw.Table>());
    final rows = (table as pw.Table).children;
    final valueRow = rows[1];

    // A title row holding fewer cells than the table has columns is laid out in
    // the leading columns only: the titles get squeezed into the narrow
    // row-number column and do not appear on the printed page.
    expect(
      rows.first.children.length,
      valueRow.children.length,
      reason: 'the classic title row must have one cell per value column',
    );
    expect(valueRow.children.length, 6, reason: '#, item, boxes, pcs, price, total');
  });
}
