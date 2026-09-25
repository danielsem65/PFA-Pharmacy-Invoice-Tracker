import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../data/excel_service.dart';
import '../../models/supplier.dart';
import '../../models/supplier_invoice.dart';

/// A field the importer can fill from a worksheet column.
///
/// Declaration order doubles as match priority: greedy assignment resolves
/// exact header matches first, so a header like "Date of invoice" reaches
/// [invoiceDate] before [invoiceNumber] can fuzzy-match the word "invoice".
enum ImportField {
  supplier,
  invoiceNumber,
  paid,
  paidDate,
  receivedDate,
  dueDate,
  invoiceDate,
  amount,
  taxPercent,
  reference,
  paymentMethod,
  product,
  boxes,
  piecesPerBox,
  pricePerBox,
  description,
  notes,
}

class _FieldInfo {
  const _FieldInfo(
    this.label,
    this.keywords, {
    this.isRequired = false,
    this.isLineItem = false,
  });

  final String label;
  final List<String> keywords;
  final bool isRequired;
  final bool isLineItem;
}

const _fields = <ImportField, _FieldInfo>{
  ImportField.supplier: _FieldInfo(
    'Supplier',
    [
      'supplier name',
      'supplier',
      'distributor',
      'vendor',
      'pharmacy',
      'store name',
      'store',
    ],
    isRequired: true,
  ),
  ImportField.invoiceNumber: _FieldInfo(
    'Invoice number',
    [
      'invoice number',
      'invoice no',
      'invoice',
      'inv no',
      'inv',
      'bill no',
      'bill number',
      'receipt no',
    ],
    isRequired: true,
  ),
  ImportField.paid: _FieldInfo(
    'Amount paid',
    ['amount paid', 'amount received', 'paid amount', 'paid', 'payment'],
  ),
  ImportField.paidDate: _FieldInfo(
    'Paid date',
    ['date paid', 'paid date', 'payment date', 'date of payment'],
  ),
  ImportField.receivedDate: _FieldInfo(
    'Received date',
    [
      'date received',
      'received date',
      'delivery date',
      'date delivered',
      'received',
    ],
  ),
  ImportField.dueDate: _FieldInfo(
    'Due date',
    ['payment due', 'due date', 'due by', 'due', 'expiry date'],
  ),
  ImportField.invoiceDate: _FieldInfo(
    'Invoice date',
    [
      'invoice date',
      'date of invoice',
      'inv date',
      'date',
    ],
    isRequired: true,
  ),
  ImportField.amount: _FieldInfo(
    'Invoice amount',
    [
      // A subtotal is the net figure the app stores, so it is preferred over a
      // total that already includes VAT.
      'subtotal',
      'sub total',
      'net total',
      'net amount',
      'total before tax',
      'invoice total',
      'total amount',
      'amount due',
      'amount',
      'total',
      'value',
      'billed',
    ],
  ),
  ImportField.taxPercent: _FieldInfo(
    'Tax %',
    ['tax percentage', 'tax rate', 'vat', 'tax'],
  ),
  ImportField.reference: _FieldInfo(
    'Ref / PO',
    ['purchase order', 'po number', 'ref po', 'reference', 'ref', 'po'],
  ),
  ImportField.paymentMethod: _FieldInfo(
    'Payment method',
    ['payment method', 'method of payment', 'mode of payment', 'method', 'mode'],
  ),
  ImportField.product: _FieldInfo(
    'Item name',
    [
      'item name',
      'product name',
      'description of goods',
      'medicine',
      'product',
      'item',
      'drug',
      'name',
    ],
    isLineItem: true,
  ),
  ImportField.boxes: _FieldInfo(
    'Boxes',
    ['boxes', 'box', 'cartons', 'packs', 'quantity', 'qty'],
    isLineItem: true,
  ),
  ImportField.piecesPerBox: _FieldInfo(
    'Pieces per box',
    [
      'pieces per box',
      'items per box',
      'pack size',
      'per box',
      'pieces',
    ],
    isLineItem: true,
  ),
  ImportField.pricePerBox: _FieldInfo(
    'Price per box',
    ['price per box', 'unit price', 'cost per box', 'price', 'cost', 'rate'],
    isLineItem: true,
  ),
  ImportField.description: _FieldInfo(
    'Description',
    ['description', 'desc', 'details', 'particulars', 'comments'],
  ),
  ImportField.notes: _FieldInfo(
    'Notes',
    ['notes', 'remark', 'remarks', 'comment'],
  ),
};

extension ImportFieldInfo on ImportField {
  String get label => _fields[this]!.label;
  bool get isRequired => _fields[this]!.isRequired;
  bool get isLineItem => _fields[this]!.isLineItem;

  /// How well a normalised header describes this field, 0 when it does not.
  double matchScore(String header) {
    if (header.isEmpty) return 0;
    var best = 0.0;
    for (final raw in _fields[this]!.keywords) {
      final keyword = normalizeHeader(raw);
      if (header == keyword) {
        best = 1;
      } else if (header.startsWith(keyword)) {
        if (0.8 > best) best = 0.8;
      } else if (header.contains(keyword)) {
        if (0.6 > best) best = 0.6;
      }
    }
    return best;
  }
}

/// Lower-cases a header and keeps only letters, digits and single spaces so
/// "Ref/PO", "ref_po" and "Ref - PO" all compare equal.
String normalizeHeader(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

/// Which worksheet column feeds which invoice field. A column index of -1 or
/// a missing key means the field is not filled from the sheet.
class ImportMapping {
  const ImportMapping(this.columns);

  const ImportMapping.empty() : columns = const {};

  final Map<ImportField, int> columns;

  int? columnOf(ImportField field) {
    final index = columns[field];
    if (index == null || index < 0) return null;
    return index;
  }

  ImportMapping withColumn(ImportField field, int? column) {
    final next = Map<ImportField, int>.of(columns);
    if (column == null || column < 0) {
      next.remove(field);
    } else {
      next[field] = column;
    }
    return ImportMapping(next);
  }

  /// Fields the importer cannot work without.
  List<ImportField> get missingRequired => [
        for (final field in ImportField.values)
          if (field.isRequired && columnOf(field) == null) field,
      ];

  bool get isUsable => missingRequired.isEmpty;

  /// True when at least one line-item column is mapped, so items will come in
  /// alongside the invoice header.
  bool get hasLineItems =>
      columnOf(ImportField.product) != null ||
      columnOf(ImportField.pricePerBox) != null;
}

/// Assigns columns to fields greedily by best score, so a column is never
/// claimed by a weak match while a strong match for it is still available.
ImportMapping detectMapping(List<String> headers) {
  final normalized = [for (final h in headers) normalizeHeader(h)];
  final scores = <ImportField, List<double>>{
    for (final field in ImportField.values)
      field: [for (final h in normalized) field.matchScore(h)],
  };

  final usedFields = <ImportField>{};
  final usedColumns = <int>{};
  final mapping = <ImportField, int>{};

  for (var round = 0; round < ImportField.values.length; round++) {
    ImportField? bestField;
    var bestColumn = -1;
    var bestScore = 0.55;
    for (final field in ImportField.values) {
      if (usedFields.contains(field)) continue;
      for (var c = 0; c < normalized.length; c++) {
        if (usedColumns.contains(c)) continue;
        final score = scores[field]![c];
        if (score > bestScore) {
          bestScore = score;
          bestField = field;
          bestColumn = c;
        }
      }
    }
    if (bestField == null) break;
    usedFields.add(bestField);
    usedColumns.add(bestColumn);
    mapping[bestField] = bestColumn;
  }

  return ImportMapping(mapping);
}

/// A row the importer could not use, kept so the user can see what was
/// dropped instead of silently losing records.
class ImportProblem {
  const ImportProblem(this.rowNumber, this.reason);

  /// 1-based, as shown in Excel.
  final int rowNumber;
  final String reason;

  @override
  String toString() => 'Row $rowNumber: $reason';
}

class InvoiceImportPlan {
  InvoiceImportPlan({
    required this.invoices,
    required this.newSuppliers,
    required this.problems,
    required this.skippedExisting,
    required this.rowsRead,
  });

  final List<SupplierInvoice> invoices;

  /// Suppliers that do not exist yet and must be created before the invoices
  /// are saved.
  final List<Supplier> newSuppliers;
  final List<ImportProblem> problems;

  /// Invoices dropped because the same supplier and number already exist.
  final int skippedExisting;
  final int rowsRead;

  bool get isEmpty => invoices.isEmpty;

  int get lineCount =>
      invoices.fold(0, (sum, i) => sum + i.lines.length);

  int get totalPesewas =>
      invoices.fold(0, (sum, i) => sum + i.totalPesewas);
}

/// Reads a worksheet into invoices, using [mapping] to decide which column
/// holds what. Rows sharing a supplier and invoice number are folded into one
/// invoice, so a sheet that lists one medicine per line still produces a
/// single invoice with several items.
InvoiceImportPlan buildImportPlan({
  required XlsxSheet sheet,
  required int headerRowIndex,
  required ImportMapping mapping,
  required List<Supplier> existingSuppliers,
  required List<SupplierInvoice> existingInvoices,
  bool skipExisting = true,
  DateTime? today,
}) {
  final problems = <ImportProblem>[];
  if (!mapping.isUsable) {
    problems.add(ImportProblem(
      headerRowIndex + 1,
      'map the ${mapping.missingRequired.map((f) => f.label).join(', ')} '
          'column${mapping.missingRequired.length == 1 ? '' : 's'} first',
    ));
    return InvoiceImportPlan(
      invoices: const [],
      newSuppliers: const [],
      problems: problems,
      skippedExisting: 0,
      rowsRead: 0,
    );
  }

  final now = today ?? DateTime.now();
  final groups = <String, _Group>{};
  final order = <String>[];
  var rowsRead = 0;

  for (var r = headerRowIndex + 1; r < sheet.rowCount; r++) {
    if (sheet.isBlank(r)) continue;
    rowsRead++;
    final reader = _RowReader(sheet.rowAt(r), mapping);
    final supplierName = reader.text(ImportField.supplier);
    if (supplierName.isEmpty) {
      problems.add(ImportProblem(r + 1, 'no supplier name'));
      continue;
    }
    if (isTotalLabel(supplierName)) continue;

    final number = reader.text(ImportField.invoiceNumber);
    final key = number.isEmpty
        ? '${supplierName.toLowerCase()}|$r'
        : '${supplierName.toLowerCase()}|${number.toLowerCase()}';
    final group = groups.putIfAbsent(
      key,
      () {
        order.add(key);
        return _Group(supplier: supplierName, firstRow: r + 1);
      },
    );
    group.absorb(reader);
  }

  final byName = <String, Supplier>{};
  for (final s in existingSuppliers) {
    byName.putIfAbsent(s.name.trim().toLowerCase(), () => s);
  }
  final newSuppliers = <Supplier>[];

  final existingKeys = <String>{};
  if (skipExisting) {
    for (final inv in existingInvoices) {
      existingKeys.add(
        '${_nameOf(inv.supplierId, existingSuppliers)}|${inv.invoiceNumber}'
            .toLowerCase(),
      );
      existingKeys.add(
        '${_nameOf(inv.supplierId, existingSuppliers)}|'
            '${dateOnly(inv.invoiceDate).toIso8601String()}',
      );
    }
  }

  final invoices = <SupplierInvoice>[];
  var skippedExisting = 0;
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final amountIncludesTax = _amountIncludesTax(
    headerRowIndex < sheet.rowCount
        ? sheet.rowAt(headerRowIndex)
        : const <Object?>[],
    mapping.columnOf(ImportField.amount),
  );

  for (final key in order) {
    final group = groups[key]!;
    final invoiceDate = group.invoiceDate ?? now;
    final receivedDate = group.receivedDate ?? invoiceDate;
    final dueDate = group.dueDate ?? invoiceDate;

    if (skipExisting &&
        existingKeys.contains(
          group.number.isEmpty
              ? '${group.supplier.toLowerCase()}|'
                  '${dateOnly(invoiceDate).toIso8601String()}'
              : '${group.supplier.toLowerCase()}|${group.number.toLowerCase()}',
        )) {
      skippedExisting++;
      continue;
    }

    // A line-item sheet often carries no invoice total, so add the items up.
    var amount = group.hasAmount
        ? group.amountPesewas
        : group.lines.fold(0, (sum, l) => sum + l.totalPesewas);
    // The app adds VAT to the amount it is handed, so when the sheet quotes a
    // total that already includes VAT the rate is taken back out first,
    // otherwise the invoice is inflated by the tax twice.
    if (amountIncludesTax && group.hasAmount && group.taxPercent > 0) {
      amount = (amount / (1 + group.taxPercent / 100)).round();
    }
    if (amount == 0 && group.lines.isEmpty) {
      problems.add(
        ImportProblem(group.firstRow, 'no amount and no items'),
      );
      continue;
    }

    final lookup = group.supplier.trim().toLowerCase();
    var supplier = byName[lookup];
    if (supplier == null) {
      supplier = Supplier(
        id: 's_xlsx_${stamp}_${newSuppliers.length}',
        name: group.supplier.trim(),
      );
      byName[lookup] = supplier;
      newSuppliers.add(supplier);
    }

    invoices.add(SupplierInvoice(
      id: 'i_xlsx_${stamp}_${invoices.length}',
      supplierId: supplier.id,
      invoiceNumber: group.number,
      invoiceDate: invoiceDate,
      receivedDate: receivedDate,
      dueDate: dueDate,
      amountPesewas: amount,
      taxRatePercent: group.taxPercent,
      amountPaidPesewas: group.paidPesewas,
      reference: group.reference,
      description: group.description,
      paidDate: group.paidDate,
      paymentMethod: group.paymentMethod,
      notes: group.notes,
      lines: group.lines,
    ));
  }

  return InvoiceImportPlan(
    invoices: invoices,
    newSuppliers: newSuppliers,
    problems: problems,
    skippedExisting: skippedExisting,
    rowsRead: rowsRead,
  );
}

/// True when the mapped amount column looks like a figure that already
/// includes VAT, as "Total" usually does on a supplier's sheet. A column
/// marked as a subtotal, a net figure or a before-tax figure does not.
bool _amountIncludesTax(List<Object?> headerRow, int? amountColumn) {
  if (amountColumn == null || amountColumn >= headerRow.length) return false;
  final heading = normalizeHeader(displayText(headerRow[amountColumn]));
  if (heading.isEmpty) return false;
  if (heading.contains('subtotal') ||
      heading.contains('sub total') ||
      heading.contains('net') ||
      heading.contains('before tax') ||
      heading.contains('exclusive')) {
    return false;
  }
  return heading.contains('total') || heading.contains('amount');
}

String _nameOf(String supplierId, List<Supplier> suppliers) {
  for (final s in suppliers) {
    if (s.id == supplierId) return s.name;
  }
  return 'Unknown';
}

/// True for the summary lines a hand-kept sheet ends with, which are not
/// invoices in their own right.
bool isTotalLabel(String text) {
  final t = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.isEmpty) return false;
  return t == 'total' ||
      t == 'subtotal' ||
      t.startsWith('total ') ||
      t.startsWith('grand total') ||
      t.contains('grand total') ||
      t.startsWith('sub total');
}

class _Group {
  _Group({required this.supplier, required this.firstRow});

  final String supplier;
  final int firstRow;

  String number = '';
  String reference = '';
  String description = '';
  String notes = '';
  DateTime? invoiceDate;
  DateTime? receivedDate;
  DateTime? dueDate;
  DateTime? paidDate;
  double taxPercent = 0;
  int amountPesewas = 0;
  bool hasAmount = false;
  int paidPesewas = 0;
  String paymentMethod = 'Cash';
  final List<InvoiceLine> lines = [];

  void absorb(_RowReader reader) {
    if (number.isEmpty) number = reader.text(ImportField.invoiceNumber);
    if (reference.isEmpty) reference = reader.text(ImportField.reference);
    if (description.isEmpty) description = reader.text(ImportField.description);
    if (notes.isEmpty) notes = reader.text(ImportField.notes);

    invoiceDate ??= reader.date(ImportField.invoiceDate);
    receivedDate ??= reader.date(ImportField.receivedDate);
    dueDate ??= reader.date(ImportField.dueDate);
    paidDate ??= reader.date(ImportField.paidDate);

    if (!hasAmount && reader.hasValue(ImportField.amount)) {
      final value = reader.number(ImportField.amount);
      if (value != null) {
        amountPesewas = (value * 100).round();
        hasAmount = true;
      }
    }
    if (paidPesewas == 0 && reader.hasValue(ImportField.paid)) {
      final value = reader.number(ImportField.paid);
      if (value != null) paidPesewas = (value * 100).round();
    }
    if (taxPercent == 0) {
      // A VAT column holding an amount rather than a rate would otherwise
      // become a tax of several hundred per cent.
      final rate = reader.number(ImportField.taxPercent) ?? 0;
      if (rate > 0 && rate <= 100) taxPercent = rate;
    }
    if (paymentMethod == 'Cash') {
      final method = matchPaymentMethod(reader.text(ImportField.paymentMethod));
      if (method != null) paymentMethod = method;
    }

    final product = reader.text(ImportField.product);
    if (product.isEmpty) return;
    if (isTotalLabel(product)) return;
    lines.add(InvoiceLine(
      name: product,
      boxes: (reader.number(ImportField.boxes) ?? 1).round().clamp(1, 100000).toInt(),
      piecesPerBox: (reader.number(ImportField.piecesPerBox) ?? 1)
          .round()
          .clamp(1, 100000)
          .toInt(),
      pricePerBoxPesewas:
          ((reader.number(ImportField.pricePerBox) ?? 0) * 100).round(),
    ));
  }
}

/// Maps a free-text payment method onto one the app knows, or null.
String? matchPaymentMethod(String text) {
  final t = text.trim().toLowerCase();
  if (t.isEmpty) return null;
  for (final method in kPaymentMethods) {
    if (method.toLowerCase() == t) return method;
  }
  for (final method in kPaymentMethods) {
    if (t.contains(method.toLowerCase())) return method;
  }
  if (t.contains('transfer') || t.contains('momo') || t.contains('mobile')) {
    return 'MoMo';
  }
  if (t.contains('card')) return 'Card';
  return null;
}

class _RowReader {
  _RowReader(this.row, this.mapping);

  final List<Object?> row;
  final ImportMapping mapping;

  Object? _raw(ImportField field) {
    final column = mapping.columnOf(field);
    if (column == null || column >= row.length) return null;
    return row[column];
  }

  String text(ImportField field) => displayText(_raw(field)).trim();

  double? number(ImportField field) => parseNumber(_raw(field));

  DateTime? date(ImportField field) => parseDate(_raw(field));

  bool hasValue(ImportField field) => displayText(_raw(field)).trim().isNotEmpty;
}

String displayText(Object? value) {
  if (value == null) return '';
  if (value is String) return value;
  if (value is double && value == value.roundToDouble() && value.abs() < 1e15) {
    return value.toStringAsFixed(0);
  }
  return value.toString();
}

/// Reads a number written as text: "1,200.50", "GH₵ 1200", "(45.00)".
double? parseNumber(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is bool) return null;
  final raw = value.toString().trim();
  if (raw.isEmpty) return null;

  var text = raw;
  var negative = false;
  if (text.startsWith('(') && text.endsWith(')')) {
    negative = true;
    text = text.substring(1, text.length - 1);
  }
  final cleaned = text.replaceAll(RegExp(r'[^0-9.\-]'), '');
  if (cleaned.isEmpty) return null;
  if (cleaned.startsWith('-')) negative = !negative;
  if (cleaned.endsWith('-')) negative = !negative;
  final parsed = double.tryParse(cleaned.replaceAll('-', ''));
  if (parsed == null) return null;
  return negative ? -parsed : parsed;
}

/// Reads a date cell, including Excel serial numbers and the day-first text
/// formats used on Ghanaian invoices.
DateTime? parseDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return dateOnly(value);
  if (value is num) return _fromSerial(value.toDouble());
  if (value is bool) return null;
  final text = value.toString().trim();
  if (text.isEmpty) return null;

  final iso = DateTime.tryParse(text);
  if (iso != null) return dateOnly(iso);

  final numeric =
      RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})$').firstMatch(text);
  if (numeric != null) {
    final a = int.parse(numeric.group(1)!);
    final b = int.parse(numeric.group(2)!);
    var year = int.parse(numeric.group(3)!);
    if (year < 100) year += year < 70 ? 2000 : 1900;
    // A value over 12 can only be the day, which settles the order; otherwise
    // day-first wins, as it does on the invoices this app replaces.
    final day = a > 12 ? a : (b > 12 ? b : a);
    final month = a > 12 ? b : (b > 12 ? a : b);
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }

  for (final pattern in const [
    'd MMM yyyy',
    'd MMMM yyyy',
    'MMM d, yyyy',
    'MMMM d, yyyy',
    'dd/mm/yyyy',
  ]) {
    try {
      return dateOnly(DateFormat(pattern).parseStrict(text));
    } catch (_) {
      // Try the next pattern.
    }
  }
  return null;
}

DateTime? _fromSerial(double serial) {
  // Excel counts whole days from 30 December 1899. The count is done in UTC so
  // that daylight saving in the reader's own country cannot shift the day.
  if (serial < 1 || serial > 2958465) return null;
  final utc = DateTime.utc(1899, 12, 30).add(Duration(days: serial.round()));
  return DateTime(utc.year, utc.month, utc.day);
}
