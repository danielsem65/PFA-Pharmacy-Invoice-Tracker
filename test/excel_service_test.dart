import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pfa_pharmacy_invoice_tracker/data/excel_service.dart';
import 'package:pfa_pharmacy_invoice_tracker/features/import/invoice_importer.dart';
import 'package:pfa_pharmacy_invoice_tracker/models/product.dart';
import 'package:pfa_pharmacy_invoice_tracker/models/supplier_invoice.dart';

import 'helpers.dart';

List<String> headersOf(XlsxSheet sheet, int row) =>
    [for (final cell in sheet.rowAt(row)) displayText(cell).trim()];

List<int> buildSampleWorkbook() {
  return buildWorkbookBytes(
    invoices: [
      invoice(
        id: 'i1',
        supplierId: 's1',
        invoiceNumber: 'INV-77',
        invoiceDate: DateTime(2026, 3, 4),
        receivedDate: DateTime(2026, 3, 6),
        dueDate: DateTime(2026, 4, 4),
        amountPesewas: 450000,
        taxRatePercent: 15,
        amountPaidPesewas: 100000,
        lines: [
          InvoiceLine(
            name: 'Artemether/Lumefantrine',
            boxes: 2,
            piecesPerBox: 12,
            pricePerBoxPesewas: 9000,
          ),
          InvoiceLine(
            name: 'ORS Sachet',
            boxes: 10,
            piecesPerBox: 1,
            pricePerBoxPesewas: 350,
          ),
        ],
      ),
    ],
    suppliers: [supplier('s1', 'Medi Trust')],
    products: [
      Product(id: 'p1', name: 'ORS Sachet', piecesPerBox: 1, pricePerBoxPesewas: 350),
    ],
    supplierNameOf: (id) => id == 's1' ? 'Medi Trust' : 'Unknown',
    exportedAt: DateTime(2026, 3, 10, 9, 30),
  );
}

void main() {
  group('Excel export', () {
    test('writes one sheet per record type plus a summary', () {
      final workbook = readXlsx(buildSampleWorkbook());
      expect(
        workbook.sheetNames,
        containsAll(<String>['Invoices', 'Invoice Items', 'Suppliers', 'Products', 'Summary']),
      );
    });

    test('leaves no empty sheet in front of the real ones', () {
      final workbook = readXlsx(buildSampleWorkbook());
      // A new workbook arrives with an empty Sheet1, which is of no use here.
      expect(workbook.sheetNames, isNot(contains('Sheet1')));
      expect(workbook.sheetNames, hasLength(5));
      // The summary is the sheet the workbook opens on.
      expect(workbook.sheetNames.first, 'Summary');
    });

    test('merges and centres the summary title across two columns', () {
      final excel = Excel.decodeBytes(buildSampleWorkbook());
      final sheet = excel.tables['Summary']!;
      final title = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      );
      expect(title.value.toString(), 'PFA Pharmacy Invoice Tracker');
      expect(title.cellStyle?.horizontalAlign, HorizontalAlign.Center);
      expect(sheet.spannedItems, contains('A1:B1'));
    });

    test('writes money as numbers in cedis, not pesewas or text', () {
      final sheet = readXlsx(buildSampleWorkbook()).sheet('Invoices');
      final subtotal = headersOf(sheet, 0).indexOf('Subtotal (GH₵)');
      expect(sheet.rowAt(1)[subtotal], isA<num>());
      expect(sheet.rowAt(1)[subtotal], closeTo(4500.0, 0.001));
    });

    test('writes dates as real dates', () {
      final sheet = readXlsx(buildSampleWorkbook()).sheet('Invoices');
      final invoiceDate = headersOf(sheet, 0).indexOf('Invoice Date');
      expect(sheet.rowAt(1)[invoiceDate], DateTime(2026, 3, 4));
    });

    test('gives every item its own row', () {
      final sheet = readXlsx(buildSampleWorkbook()).sheet('Invoice Items');
      expect(sheet.rowCount, 3); // heading plus two items
      final product = headersOf(sheet, 0).indexOf('Product');
      expect(displayText(sheet.rowAt(2)[product]), 'ORS Sachet');
    });

    test('writes the summary totals in as numbers too', () {
      final sheet = readXlsx(buildSampleWorkbook()).sheet('Summary');

      Object? valueOf(String label) {
        for (var r = 0; r < sheet.rowCount; r++) {
          if (displayText(sheet.rowAt(r)[0]).trim() == label) {
            return sheet.rowAt(r)[1];
          }
        }
        fail('the summary has no row labelled "$label"');
      }

      num totalOf(String label) => valueOf(label)! as num;

      expect(totalOf('Total billed (GH₵)'), closeTo(5175.00, 0.001));
      expect(totalOf('Total paid (GH₵)'), closeTo(1000.00, 0.001));
      expect(totalOf('Outstanding (GH₵)'), closeTo(4175.00, 0.001));
      expect(valueOf('Invoices'), '1');
    });

    test('records when the export was made', () {
      final sheet = readXlsx(buildSampleWorkbook()).sheet('Summary');
      final exported = [
        for (var r = 0; r < sheet.rowCount; r++)
          if (displayText(sheet.rowAt(r)[0]).trim() == 'Exported')
            displayText(sheet.rowAt(r)[1]).trim(),
      ];
      expect(exported, ['10/03/2026 09:30']);
    });
  });

  group('Excel re-import', () {
    test('reads back the invoices it wrote', () {
      final workbook = readXlsx(buildSampleWorkbook());
      final sheet = workbook.sheet('Invoices');
      final mapping = detectMapping(headersOf(sheet, 0));

      final plan = buildImportPlan(
        sheet: sheet,
        headerRowIndex: 0,
        mapping: mapping,
        existingSuppliers: const [],
        existingInvoices: const [],
      );

      expect(plan.invoices, hasLength(1));
      final imported = plan.invoices.single;
      expect(imported.invoiceNumber, 'INV-77');
      expect(imported.invoiceDate, DateTime(2026, 3, 4));
      expect(imported.receivedDate, DateTime(2026, 3, 6));
      expect(imported.dueDate, DateTime(2026, 4, 4));
      expect(imported.amountPesewas, 450000);
      expect(imported.taxRatePercent, 15);
      expect(imported.amountPaidPesewas, 100000);
      expect(imported.totalPesewas, 517500);
      // The heading row has no item columns, so a re-import must not invent
      // any items.
      expect(imported.lines, isEmpty);
      expect(plan.newSuppliers.single.name, 'Medi Trust');
      expect(plan.newSuppliers.single.id, imported.supplierId);
    });

    test('reads the item sheet back as lines on the invoice', () {
      final workbook = readXlsx(buildSampleWorkbook());
      final invoices = workbook.sheet('Invoices');
      final items = workbook.sheet('Invoice Items');

      // A hand-kept ledger carries the invoice details and the item details on
      // the same row, so join the two sheets into one the way such a ledger
      // looks: the invoice's columns, then the item's columns.
      final merged = XlsxSheet('merged', [
        [...invoices.rows.first, ...items.rows.first.skip(2)],
        for (final row in items.rows.skip(1))
          [...invoices.rows[1], ...row.skip(2)],
      ]);

      // The item columns sit after the sixteen invoice columns; this is what
      // the user sees and confirms on the mapping step.
      final mapping = ImportMapping({
        ImportField.supplier: 0,
        ImportField.invoiceNumber: 1,
        ImportField.invoiceDate: 4,
        ImportField.taxPercent: 7,
        ImportField.amount: 8,
        ImportField.product: 16,
        ImportField.boxes: 17,
        ImportField.piecesPerBox: 18,
        ImportField.pricePerBox: 19,
      });

      final plan = buildImportPlan(
        sheet: merged,
        headerRowIndex: 0,
        mapping: mapping,
        existingSuppliers: const [],
        existingInvoices: const [],
      );

      expect(plan.invoices, hasLength(1));
      final imported = plan.invoices.single;
      final lines = imported.lines;
      expect(lines, hasLength(2));
      expect(lines.first.name, 'Artemether/Lumefantrine');
      expect(lines.first.boxes, 2);
      expect(lines.first.piecesPerBox, 12);
      expect(lines.first.pricePerBoxPesewas, 9000);
      expect(lines.last.name, 'ORS Sachet');
      expect(lines.last.boxes, 10);
      // The net amount and the rate are read apart, so the total the app works
      // out is the total the sheet wrote.
      expect(imported.amountPesewas, 450000);
      expect(imported.taxRatePercent, 15);
      expect(imported.totalPesewas, 517500);
    });

    test('takes VAT back out of a total that already includes it', () {
      final sheet = XlsxSheet('Sheet1', const [
        ['Supplier', 'Invoice No', 'Date', 'Tax %', 'Total'],
        ['Medi Trust', 'INV-77', '04/03/2026', '15', '5175.00'],
      ]);
      final plan = buildImportPlan(
        sheet: sheet,
        headerRowIndex: 0,
        mapping: detectMapping(const [
          'Supplier',
          'Invoice No',
          'Date',
          'Tax %',
          'Total',
        ]),
        existingSuppliers: const [],
        existingInvoices: const [],
      );

      final imported = plan.invoices.single;
      expect(imported.taxRatePercent, 15);
      // 5175.00 less 15% VAT is the 4500.00 the supplier billed.
      expect(imported.amountPesewas, 450000);
      expect(imported.totalPesewas, 517500);
    });

    test('leaves the amount alone when the sheet gives no rate to remove', () {
      final sheet = XlsxSheet('Sheet1', const [
        ['Supplier', 'Invoice No', 'Date', 'Total'],
        ['Medi Trust', 'INV-77', '04/03/2026', '4500.00'],
      ]);
      final plan = buildImportPlan(
        sheet: sheet,
        headerRowIndex: 0,
        mapping: detectMapping(const [
          'Supplier',
          'Invoice No',
          'Date',
          'Total',
        ]),
        existingSuppliers: const [],
        existingInvoices: const [],
      );
      expect(plan.invoices.single.amountPesewas, 450000);
    });

    test('refuses a VAT column that holds an amount rather than a rate', () {
      final sheet = XlsxSheet('Sheet1', const [
        ['Supplier', 'Invoice No', 'Date', 'VAT (GH₵)', 'Total'],
        ['Medi Trust', 'INV-77', '04/03/2026', '675.00', '5175.00'],
      ]);
      final plan = buildImportPlan(
        sheet: sheet,
        headerRowIndex: 0,
        mapping: detectMapping(const [
          'Supplier',
          'Invoice No',
          'Date',
          'VAT (GH₵)',
          'Total',
        ]),
        existingSuppliers: const [],
        existingInvoices: const [],
      );
      expect(plan.invoices.single.taxRatePercent, 0);
    });
  });

  group('column detection', () {
    test('matches the headings on a hand-kept ledger', () {
      final mapping = detectMapping(const [
        'Date',
        'Supplier',
        'Invoice No',
        'Description',
        'Quantity',
        'Price',
        'Total',
        'Paid',
      ]);

      expect(mapping.columnOf(ImportField.supplier), 1);
      expect(mapping.columnOf(ImportField.invoiceNumber), 2);
      expect(mapping.columnOf(ImportField.invoiceDate), 0);
      expect(mapping.columnOf(ImportField.paid), 7);
      expect(mapping.columnOf(ImportField.amount), 6);
      expect(mapping.columnOf(ImportField.product), 3);
      expect(mapping.columnOf(ImportField.boxes), 4);
      expect(mapping.columnOf(ImportField.pricePerBox), 5);
      // Nothing on this sheet says how many items are in a box.
      expect(mapping.columnOf(ImportField.piecesPerBox), isNull);
      expect(mapping.isUsable, isTrue);
    });

    test('never gives one column to two fields', () {
      final mapping = detectMapping(const [
        'Invoice No',
        'Invoice Date',
        'Amount Paid',
        'Amount Due',
      ]);
      final columns = mapping.columns.values.toList();
      expect(columns.toSet().length, columns.length);
      expect(mapping.columnOf(ImportField.invoiceNumber), 0);
      expect(mapping.columnOf(ImportField.invoiceDate), 1);
      expect(mapping.columnOf(ImportField.paid), 2);
      expect(mapping.columnOf(ImportField.amount), 3);
    });

    test('reports the headings it still needs', () {
      const mapping = ImportMapping({ImportField.supplier: 0});
      expect(mapping.isUsable, isFalse);
      expect(
        mapping.missingRequired,
        containsAll(<ImportField>[
          ImportField.invoiceNumber,
          ImportField.invoiceDate,
        ]),
      );
      // An invoice total is not required: the items can be added up instead.
      expect(ImportField.amount.isRequired, isFalse);
      expect(mapping.isUsable, isFalse);
    });

    test('is usable with only a supplier, number and date mapped', () {
      const mapping = ImportMapping({
        ImportField.supplier: 0,
        ImportField.invoiceNumber: 1,
        ImportField.invoiceDate: 2,
      });
      expect(mapping.isUsable, isTrue);
      expect(mapping.missingRequired, isEmpty);
    });

    test('normalises punctuation and spacing in headings', () {
      expect(normalizeHeader('Ref/PO'), 'ref po');
      expect(normalizeHeader('  Invoice   No. '), 'invoice no');
      expect(normalizeHeader('Tax %'), 'tax');
    });
  });

  group('import from a hand-kept ledger', () {
    XlsxSheet ledger() => XlsxSheet('Sheet1', const [
          ['JANUARY 2026 PURCHASES'],
          [],
          ['Date', 'Supplier', 'Invoice No', 'Item', 'Boxes', 'Per box', 'Price', 'Total', 'Paid'],
          ['04/03/2026', 'Medi Trust', 'INV-77', 'Artemether', 2, 12, '90.00', '4500.00', '1000.00'],
          ['04/03/2026', 'Medi Trust', 'INV-77', 'ORS Sachet', 10, 1, '35.00', '', ''],
          ['05/03/2026', 'City Pharmacy', 'CP-3', 'Paracetamol', 5, 1, '12.00', '210.00', ''],
          ['TOTAL', '', '', '', '', '', '', '4710.00', '1000.00'],
        ]);

    test('joins item rows into one invoice per supplier and number', () {
      final plan = buildImportPlan(
        sheet: ledger(),
        headerRowIndex: 2,
        mapping: detectMapping(const [
          'Date',
          'Supplier',
          'Invoice No',
          'Item',
          'Boxes',
          'Per box',
          'Price',
          'Total',
          'Paid',
        ]),
        existingSuppliers: const [],
        existingInvoices: const [],
      );

      expect(plan.invoices, hasLength(2));
      final first = plan.invoices.first;
      expect(first.invoiceNumber, 'INV-77');
      expect(first.amountPesewas, 450000);
      expect(first.amountPaidPesewas, 100000);
      expect(first.lines, hasLength(2));
      expect(first.lines.first.name, 'Artemether');
      expect(first.lines.first.boxes, 2);
      expect(first.lines.last.name, 'ORS Sachet');
      expect(plan.newSuppliers, hasLength(2));
    });

    test('ignores the total line and the title above the headings', () {
      final plan = buildImportPlan(
        sheet: ledger(),
        headerRowIndex: 2,
        mapping: detectMapping(const [
          'Date',
          'Supplier',
          'Invoice No',
          'Item',
          'Boxes',
          'Per box',
          'Price',
          'Total',
          'Paid',
        ]),
        existingSuppliers: const [],
        existingInvoices: const [],
      );
      expect(plan.invoices.map((i) => i.invoiceNumber), isNot(contains('TOTAL')));
      expect(plan.invoices, hasLength(2));
    });

    test('adds items up when the sheet has no invoice total', () {
      final sheet = XlsxSheet('Sheet1', const [
        ['Supplier', 'Invoice No', 'Date', 'Item', 'Boxes', 'Price'],
        ['Medi Trust', 'INV-9', '01/02/2026', 'ORS Sachet', 10, '35.00'],
      ]);
      final plan = buildImportPlan(
        sheet: sheet,
        headerRowIndex: 0,
        mapping: detectMapping(const [
          'Supplier',
          'Invoice No',
          'Date',
          'Item',
          'Boxes',
          'Price',
        ]),
        existingSuppliers: const [],
        existingInvoices: const [],
      );
      expect(plan.invoices.single.amountPesewas, 35000);
    });

    test('reuses an existing supplier instead of creating a second one', () {
      final existing = [supplier('s9', 'Medi Trust')];
      final sheet = XlsxSheet('Sheet1', const [
        ['Supplier', 'Invoice No', 'Date', 'Total'],
        ['medi trust', 'INV-77', '04/03/2026', '4500.00'],
      ]);
      final plan = buildImportPlan(
        sheet: sheet,
        headerRowIndex: 0,
        mapping: detectMapping(const ['Supplier', 'Invoice No', 'Date', 'Total']),
        existingSuppliers: existing,
        existingInvoices: const [],
      );
      expect(plan.newSuppliers, isEmpty);
      expect(plan.invoices.single.supplierId, 's9');
    });

    test('skips an invoice that is already in the app', () {
      final sheet = XlsxSheet('Sheet1', const [
        ['Supplier', 'Invoice No', 'Date', 'Total'],
        ['Medi Trust', 'INV-77', '04/03/2026', '4500.00'],
        ['Medi Trust', 'INV-78', '05/03/2026', '900.00'],
      ]);
      final existing = [
        invoice(id: 'old', supplierId: 's1', invoiceNumber: 'INV-77'),
      ];

      final skipped = buildImportPlan(
        sheet: sheet,
        headerRowIndex: 0,
        mapping: detectMapping(const ['Supplier', 'Invoice No', 'Date', 'Total']),
        existingSuppliers: [supplier('s1', 'Medi Trust')],
        existingInvoices: existing,
      );
      expect(skipped.invoices.map((i) => i.invoiceNumber), ['INV-78']);
      expect(skipped.skippedExisting, 1);

      final kept = buildImportPlan(
        sheet: sheet,
        headerRowIndex: 0,
        mapping: detectMapping(const ['Supplier', 'Invoice No', 'Date', 'Total']),
        existingSuppliers: [supplier('s1', 'Medi Trust')],
        existingInvoices: existing,
        skipExisting: false,
      );
      expect(kept.invoices, hasLength(2));
      expect(kept.skippedExisting, 0);
    });

    test('reports a row it could not use instead of dropping it quietly', () {
      final sheet = XlsxSheet('Sheet1', const [
        ['Supplier', 'Invoice No', 'Date', 'Total'],
        ['', 'INV-1', '04/03/2026', '4500.00'],
      ]);
      final plan = buildImportPlan(
        sheet: sheet,
        headerRowIndex: 0,
        mapping: detectMapping(const ['Supplier', 'Invoice No', 'Date', 'Total']),
        existingSuppliers: const [],
        existingInvoices: const [],
      );
      expect(plan.invoices, isEmpty);
      expect(plan.problems.single.reason, contains('no supplier'));
    });

    test('refuses to run until the required headings are mapped', () {
      final plan = buildImportPlan(
        sheet: ledger(),
        headerRowIndex: 2,
        mapping: const ImportMapping({ImportField.product: 3}),
        existingSuppliers: const [],
        existingInvoices: const [],
      );
      expect(plan.invoices, isEmpty);
      expect(plan.problems.single.reason, contains('map'));
    });
  });

  group('value parsing', () {
    test('reads money written as text', () {
      expect(parseNumber('1,200.50'), 1200.50);
      expect(parseNumber('GH₵ 980'), 980);
      expect(parseNumber('GH¢980.00'), 980);
      expect(parseNumber(4500.0), 4500.0);
      expect(parseNumber('(45.00)'), -45.0);
      expect(parseNumber('45.00-'), -45.0);
      expect(parseNumber(''), isNull);
      expect(parseNumber('n/a'), isNull);
    });

    test('reads day-first dates, as invoices here are written', () {
      expect(parseDate('04/03/2026'), DateTime(2026, 3, 4));
      expect(parseDate('31/12/2026'), DateTime(2026, 12, 31));
      expect(parseDate('13/04/2026'), DateTime(2026, 4, 13));
      expect(parseDate('2026-03-04'), DateTime(2026, 3, 4));
      expect(parseDate('4 Mar 2026'), DateTime(2026, 3, 4));
      expect(parseDate('Mar 4, 2026'), DateTime(2026, 3, 4));
    });

    test('falls back to month-first when only that can be right', () {
      expect(parseDate('04/13/2026'), DateTime(2026, 4, 13));
    });

    test('reads an Excel serial date', () {
      // Excel counts days from 30 December 1899, so 44927 is 1 Jan 2023.
      expect(parseDate(44927.0), DateTime(2023, 1, 1));
      expect(parseDate(0.5), isNull); // a time of day, not a date
    });

    test('gives up on nonsense rather than guessing', () {
      expect(parseDate('sometime'), isNull);
      expect(parseDate(null), isNull);
      expect(parseDate(DateTime(2026, 3, 4, 17, 5)), DateTime(2026, 3, 4));
    });
  });

  test('a file that is not a workbook is refused with a clear message', () {
    expect(
      () => readXlsx(List<int>.filled(64, 7)),
      throwsA(isA<FormatException>()),
    );
  });
}
