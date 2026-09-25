import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../models/product.dart';
import '../models/supplier.dart';
import '../models/supplier_invoice.dart';

/// One worksheet read from a workbook, flattened to a dense grid of plain
/// [String] / [num] / [bool] / [DateTime] values.
///
/// The excel package's typed cells are unwrapped here so the importer and its
/// tests work with plain values instead of that package's API.
class XlsxSheet {
  XlsxSheet(this.name, this.rows);

  final String name;

  /// Row-major grid, already widened so every row has [columnCount] cells.
  final List<List<Object?>> rows;

  int get rowCount => rows.length;

  int get columnCount =>
      rows.fold<int>(0, (widest, r) => r.length > widest ? r.length : widest);

  /// A row padded to [columnCount] so callers can index columns freely.
  List<Object?> rowAt(int index) {
    if (index < 0 || index >= rows.length) {
      return List<Object?>.filled(columnCount, null);
    }
    final row = rows[index];
    if (row.length == columnCount) return row;
    return [
      ...row,
      ...List<Object?>.filled(columnCount - row.length, null),
    ];
  }

  /// True when the row has no text and no numbers — used to drop trailing
  /// blank rows and spacer lines inside a sheet.
  bool isBlank(int index) {
    if (index < 0 || index >= rows.length) return true;
    for (final cell in rows[index]) {
      if (cell == null) continue;
      if (cell is String && cell.trim().isEmpty) continue;
      return false;
    }
    return true;
  }
}

class XlsxWorkbook {
  XlsxWorkbook(this.sheets);

  final List<XlsxSheet> sheets;

  List<String> get sheetNames => [for (final s in sheets) s.name];

  XlsxSheet sheet(String name) => sheets.firstWhere((s) => s.name == name);
}

/// Opens a workbook file, throwing a [FormatException] with a message fit for
/// the user when the bytes are not a readable .xlsx file.
XlsxWorkbook readXlsx(List<int> bytes) {
  final Excel excel;
  try {
    excel = Excel.decodeBytes(bytes);
  } catch (_) {
    throw const FormatException(
      'This file could not be opened as an Excel workbook (.xlsx).',
    );
  }
  return XlsxWorkbook([
    for (final entry in excel.tables.entries)
      XlsxSheet(entry.key, _readSheet(entry.value)),
  ]);
}

List<List<Object?>> _readSheet(Sheet sheet) {
  final width = sheet.maxColumns;
  return [
    for (var r = 0; r < sheet.maxRows; r++)
      [
        for (var c = 0; c < width; c++) plainValue(sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
        ).value),
      ],
  ];
}

/// Unwraps one typed cell into a plain Dart value.
Object? plainValue(CellValue? cell) {
  if (cell == null) return null;
  return switch (cell) {
    final TextCellValue v => textValue(v),
    final IntCellValue v => v.value,
    final DoubleCellValue v => v.value,
    final BoolCellValue v => v.value,
    final DateCellValue v => v.asDateTimeLocal(),
    final DateTimeCellValue v => v.asDateTimeLocal(),
    // Times are not used by any sheet column, so the readable form is enough.
    final TimeCellValue v => v.toString(),
    // A formula cell keeps no cached result, so the expression is all we can
    // offer. Sheets meant for import should hold values, not formulas.
    final FormulaCellValue v => v.formula,
  };
}

/// A cell's text. The package keeps rich text as a span tree, and its own
/// span prints the text of the whole tree, so one call covers both.
String textValue(TextCellValue cell) => cell.value.toString();

final _headerStyle = CellStyle(
  bold: true,
  fontColorHex: ExcelColor.white,
  backgroundColorHex: ExcelColor.cyan800,
  verticalAlign: VerticalAlign.Center,
);

final _moneyStyle = CellStyle(
  numberFormat: NumFormat.custom(formatCode: '#,##0.00'),
  horizontalAlign: HorizontalAlign.Right,
);

final _dateStyle = CellStyle(
  numberFormat: NumFormat.custom(formatCode: 'dd/mm/yyyy'),
  horizontalAlign: HorizontalAlign.Right,
);

final _wrapStyle = CellStyle(textWrapping: TextWrapping.WrapText);

final _labelStyle = CellStyle(bold: true);

final _titleStyle = CellStyle(bold: true, fontSize: 14);

/// Builds the .xlsx export: a summary plus one sheet per record type.
///
/// Money is written as a real number (not text) and dates as real dates, so
/// the workbook can be summed, sorted and pivoted in Excel straight away.
List<int> buildWorkbookBytes({
  required List<SupplierInvoice> invoices,
  required List<Supplier> suppliers,
  required List<Product> products,
  required String Function(String supplierId) supplierNameOf,
  DateTime? exportedAt,
}) {
  final excel = Excel.createExcel();
  _buildInvoicesSheet(excel, invoices, supplierNameOf);
  _buildInvoiceItemsSheet(excel, invoices, supplierNameOf);
  _buildSuppliersSheet(excel, suppliers);
  _buildProductsSheet(excel, products);
  _buildSummarySheet(excel, invoices, suppliers, products, exportedAt);

  final bytes = excel.encode();
  if (bytes == null) {
    throw StateError('The Excel workbook could not be encoded.');
  }
  return bytes;
}

void _buildInvoicesSheet(
  Excel excel,
  List<SupplierInvoice> invoices,
  String Function(String supplierId) supplierNameOf,
) {
  final sheet = excel['Invoices'];
  // Item detail lives in its own sheet: one row per medicine keeps the
  // Invoices sheet readable and lets Excel pivot it. It also means this
  // workbook can be read back in by ⋮ → Import invoices from Excel.
  _writeHeader(sheet, const [
    'Supplier',
    'Invoice No',
    'Ref/PO',
    'Description',
    'Invoice Date',
    'Received Date',
    'Due Date',
    'Tax %',
    'Subtotal (GH₵)',
    'Total (GH₵)',
    'Paid (GH₵)',
    'Balance (GH₵)',
    'Status',
    'Payment Method',
    'Paid Date',
    'Notes',
  ], const [
    22.0, 14.0, 14.0, 26.0, 12.0, 14.0, 12.0, 8.0, 14.0, 14.0, 13.0, 14.0,
    13.0, 16.0, 12.0, 26.0,
  ]);

  for (final inv in invoices) {
    final row = sheet.maxRows;
    sheet.appendRow([
      TextCellValue(supplierNameOf(inv.supplierId)),
      TextCellValue(inv.invoiceNumber),
      TextCellValue(inv.reference),
      TextCellValue(inv.description),
      _dateCell(inv.invoiceDate),
      _dateCell(inv.receivedDate),
      _dateCell(inv.dueDate),
      DoubleCellValue(inv.taxRatePercent),
      _moneyCell(inv.amountPesewas),
      _moneyCell(inv.totalPesewas),
      _moneyCell(inv.amountPaidPesewas),
      _moneyCell(inv.balancePesewas),
      TextCellValue(inv.statusLabel),
      TextCellValue(inv.paymentMethod),
      _nullableDateCell(inv.paidDate),
      TextCellValue(inv.notes),
    ]);
    _styleDataRow(
      sheet,
      row,
      money: const {8, 9, 10, 11},
      dates: const {4, 5, 6, 14},
      wrap: const {3, 15},
    );
  }
}

void _buildInvoiceItemsSheet(
  Excel excel,
  List<SupplierInvoice> invoices,
  String Function(String supplierId) supplierNameOf,
) {
  final sheet = excel['Invoice Items'];
  _writeHeader(
    sheet,
    const [
      'Supplier',
      'Invoice No',
      'Product',
      'Boxes',
      'Pieces per box',
      'Price per box (GH₵)',
      'Line total (GH₵)',
    ],
    const [22.0, 14.0, 32.0, 10.0, 15.0, 19.0, 17.0],
  );
  for (final inv in invoices) {
    for (final line in inv.lines) {
      final row = sheet.maxRows;
      sheet.appendRow([
        TextCellValue(supplierNameOf(inv.supplierId)),
        TextCellValue(inv.invoiceNumber),
        TextCellValue(line.name),
        IntCellValue(line.boxes),
        IntCellValue(line.piecesPerBox),
        _moneyCell(line.pricePerBoxPesewas),
        _moneyCell(line.totalPesewas),
      ]);
      _styleDataRow(sheet, row, money: const {5, 6});
    }
  }
}

void _buildSuppliersSheet(Excel excel, List<Supplier> suppliers) {
  final sheet = excel['Suppliers'];
  _writeHeader(
    sheet,
    const ['Name', 'Phone', 'Location', 'Notes'],
    const [26.0, 16.0, 20.0, 40.0],
  );
  for (final s in suppliers) {
    sheet.appendRow([
      TextCellValue(s.name),
      TextCellValue(s.phone),
      TextCellValue(s.location),
      TextCellValue(s.notes),
    ]);
  }
}

void _buildProductsSheet(Excel excel, List<Product> products) {
  final sheet = excel['Products'];
  _writeHeader(
    sheet,
    const ['Product', 'Pieces per box', 'Price per box (GH₵)', 'Notes'],
    const [30.0, 15.0, 19.0, 40.0],
  );
  for (final p in products) {
    final row = sheet.maxRows;
    sheet.appendRow([
      TextCellValue(p.name),
      IntCellValue(p.piecesPerBox),
      _moneyCell(p.pricePerBoxPesewas),
      TextCellValue(p.notes),
    ]);
    _styleDataRow(sheet, row, money: const {2});
  }
}

void _buildSummarySheet(
  Excel excel,
  List<SupplierInvoice> invoices,
  List<Supplier> suppliers,
  List<Product> products,
  DateTime? exportedAt,
) {
  final now = exportedAt ?? DateTime.now();
  final sheet = excel['Summary'];

  var billed = 0;
  var paid = 0;
  var outstanding = 0;
  var open = 0;
  var overdue = 0;
  for (final inv in invoices) {
    billed += inv.totalPesewas;
    paid += inv.amountPaidPesewas;
    outstanding += inv.balancePesewas;
    final status = inv.statusAt(now);
    if (status == InvoiceStatus.overdue) {
      overdue++;
    } else if (status == InvoiceStatus.open || status == InvoiceStatus.partiallyPaid) {
      open++;
    }
  }

  void line(String label, String value) {
    final row = sheet.maxRows;
    sheet.appendRow([TextCellValue(label), TextCellValue(value)]);
    sheet.row(row)[0]?.cellStyle = _labelStyle;
  }

  /// Totals go in as numbers, so they can be summed in Excel like any other.
  void moneyLine(String label, int pesewas) {
    final row = sheet.maxRows;
    sheet.appendRow([TextCellValue(label), _moneyCell(pesewas)]);
    final cells = sheet.row(row);
    cells[0]?.cellStyle = _labelStyle;
    cells[1]?.cellStyle = _moneyStyle;
  }

  sheet.setColumnWidth(0, 26);
  sheet.setColumnWidth(1, 18);

  final title = sheet.maxRows;
  sheet.appendRow([TextCellValue('PFA Pharmacy Invoice Tracker')]);
  sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: title))
      .cellStyle = _titleStyle;
  line('Exported', DateFormat('dd/MM/yyyy HH:mm').format(now));
  line('Invoices', '${invoices.length}');
  line('Suppliers', '${suppliers.length}');
  line('Products', '${products.length}');
  moneyLine('Total billed (GH₵)', billed);
  moneyLine('Total paid (GH₵)', paid);
  moneyLine('Outstanding (GH₵)', outstanding);
  line('Open / partly paid', '$open');
  line('Overdue', '$overdue');
}

void _writeHeader(Sheet sheet, List<String> headers, List<double> widths) {
  for (var i = 0; i < headers.length; i++) {
    sheet.setColumnWidth(i, i < widths.length ? widths[i] : 14);
  }
  final row = sheet.maxRows;
  sheet.appendRow([for (final h in headers) TextCellValue(h)]);
  for (final cell in sheet.row(row)) {
    cell?.cellStyle = _headerStyle;
  }
  sheet.setRowHeight(row, 24);
}

void _styleDataRow(
  Sheet sheet,
  int row, {
  Set<int> money = const {},
  Set<int> dates = const {},
  Set<int> wrap = const {},
}) {
  final cells = sheet.row(row);
  for (var c = 0; c < cells.length; c++) {
    final cell = cells[c];
    if (cell == null) continue;
    if (money.contains(c)) {
      cell.cellStyle = _moneyStyle;
    } else if (dates.contains(c)) {
      cell.cellStyle = _dateStyle;
    } else if (wrap.contains(c)) {
      cell.cellStyle = _wrapStyle;
    }
  }
}

DoubleCellValue _moneyCell(int pesewas) => DoubleCellValue(pesewas / 100);

DateCellValue _dateCell(DateTime date) =>
    DateCellValue(year: date.year, month: date.month, day: date.day);

CellValue? _nullableDateCell(DateTime? date) =>
    date == null ? null : _dateCell(date);
