import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/format.dart';
import '../models/business_profile.dart';
import '../models/print_settings.dart';
import '../models/supplier.dart';
import '../models/supplier_invoice.dart';
import 'invoice_print_sheet.dart';

/// Builds the A4 PDF for one invoice in the chosen layout. Every layout is
/// monochrome: black ink on white, with grey only for rules and shading, so it
/// photocopies and scans cleanly.
Future<Uint8List> buildInvoicePdf(
  SupplierInvoice invoice, {
  Supplier? supplier,
  BusinessProfile? profile,
  required InvoicePrintLayout layout,
  DateTime? printedOn,
}) {
  final sheet = buildInvoicePrintSheet(
    invoice,
    supplier: supplier,
    profile: profile,
    printedOn: printedOn,
  );
  final fonts = PrintFonts.instance;

  final doc = pw.Document(
    title: '${sheet.invoiceNumber} — ${sheet.supplierName}',
    author: sheet.businessName.isEmpty ? 'PFA Pharmacy' : sheet.businessName,
    creator: 'PFA Pharmacy Invoice Tracker',
  );

  switch (layout) {
    case InvoicePrintLayout.classicForm:
      doc.addPage(_classicFormPage(sheet, fonts));
    case InvoicePrintLayout.splitLedger:
      doc.addPage(_splitLedgerPage(sheet, fonts));
    case InvoicePrintLayout.paymentVoucher:
      doc.addPage(_paymentVoucherPage(sheet, fonts));
  }

  return doc.save();
}

/// The fonts used on the page. Segoe UI ships with Windows and carries the cedi
/// sign, so it is used when it can be found; the base-14 fallback cannot draw
/// '₵' and would print a blank box, so there the currency is spelled out.
class PrintFonts {
  PrintFonts._(this.regular, this.bold, this.hasCediSign);

  final pw.Font regular;
  final pw.Font bold;

  /// True when [regular] can draw '₵'.
  final bool hasCediSign;

  static PrintFonts? _instance;

  static PrintFonts get instance => _instance ??= _load();

  static PrintFonts _load() {
    final windowsDir = Platform.environment['WINDIR'] ?? 'C:/Windows';
    try {
      final regular = File('$windowsDir/Fonts/segoeui.ttf');
      if (regular.existsSync()) {
        return PrintFonts._(
          pw.Font.ttf(_fontData(regular)),
          pw.Font.ttf(_fontData(File('$windowsDir/Fonts/segoeuib.ttf'))),
          true,
        );
      }
    } catch (_) {
      // No usable system font: the base-14 fonts below always work.
    }
    return PrintFonts._(pw.Font.helvetica(), pw.Font.helveticaBold(), false);
  }

  /// [pw.Font.ttf] wants a [ByteData] view, not a bare byte list.
  static ByteData _fontData(File file) {
    final bytes = file.readAsBytesSync();
    return bytes.buffer.asByteData(bytes.offsetInBytes, bytes.lengthInBytes);
  }

  pw.TextStyle text(
    double size, {
    bool bold = false,
    PdfColor color = _body,
    double spacing = 0,
  }) {
    return pw.TextStyle(
      font: bold ? this.bold : regular,
      fontSize: size,
      color: color,
      letterSpacing: spacing,
    );
  }

  /// Money with the cedi sign when the font can draw it, "GHS" spelled out
  /// when it cannot. The rest of the string still comes from the app's own
  /// formatter so both paths always agree.
  String money(int pesewas) {
    final formatted = formatPesewas(pesewas);
    return hasCediSign ? formatted : formatted.replaceFirst('₵', 'GHS ');
  }
}

// The monochrome palette. Nothing here is colourful, on purpose. Body text is a
// dark grey rather than pure black so the page photocopies and scans lighter;
// only the handful of things that must catch the eye — headings, the grand
// total — stay true black.
const PdfColor _ink = PdfColors.black;
const PdfColor _body = PdfColors.grey800;
const PdfColor _muted = PdfColors.grey600;
const PdfColor _rule = PdfColors.grey500;
const PdfColor _hairline = PdfColors.grey300;
const PdfColor _wash = PdfColors.grey100;
const PdfColor _paper = PdfColors.white;

const PdfPageFormat _a4 = PdfPageFormat.a4;

const double _margin = 32;

pw.Widget _label(String text, PrintFonts f, {PdfColor color = _muted}) {
  return pw.Text(
    text.toUpperCase(),
    style: f.text(7, bold: true, color: color, spacing: 0.8),
  );
}

/// Detail values are regular weight. Only headings and totals are bold, which
/// is what stops a page of fields reading as a wall of ink.
pw.Widget _value(
  String text,
  PrintFonts f, {
  double size = 10,
  bool bold = false,
}) {
  return pw.Text(text, style: f.text(size, bold: bold));
}

/// A label over a value, the building block of every details block.
pw.Widget _field(String label, String value, PrintFonts f, {double size = 10}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: <pw.Widget>[
      _label(label, f),
      pw.SizedBox(height: 2),
      _value(value, f, size: size),
    ],
  );
}

/// A box with a hairline border. A light [fill] is used for shaded blocks so the
/// page still reads in pure black and white.
pw.Widget _panel(
  pw.Widget child, {
  PdfColor fill = _paper,
  double borderWidth = 0.7,
  double padding = 10,
  PdfColor borderColor = _hairline,
}) {
  return pw.Container(
    width: double.infinity,
    padding: pw.EdgeInsets.all(padding),
    decoration: pw.BoxDecoration(
      color: fill,
      border: pw.Border.all(color: borderColor, width: borderWidth),
      borderRadius: pw.BorderRadius.circular(2),
    ),
    child: child,
  );
}

pw.Widget _hairlineRule({double thickness = 0.5, PdfColor color = _hairline}) {
  return pw.Divider(height: thickness, thickness: thickness, color: color);
}

pw.Widget _thickRule() {
  return pw.Divider(height: 0.9, thickness: 0.9, color: _rule);
}

/// Evenly spaced label/value pairs laid out in [columns] columns per row. A
/// short last row is padded so the columns still line up.
pw.Widget _grid(
  List<List<String>> rows,
  PrintFonts f, {
  int columns = 3,
  double fieldSize = 10,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: <pw.Widget>[
      for (final row in rows) ...<pw.Widget>[
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            for (var i = 0; i < row.length; i += 2)
              pw.Expanded(
                child: pw.Padding(
                  padding: pw.EdgeInsets.only(
                    right: i + 2 < row.length ? 12 : 0,
                    bottom: 10,
                  ),
                  child: _field(row[i], row[i + 1], f, size: fieldSize),
                ),
              ),
            for (var i = row.length ~/ 2; i < columns; i++)
              pw.Expanded(child: pw.SizedBox()),
          ],
        ),
      ],
    ],
  );
}

pw.Widget _pageStamp(pw.Context ctx, PrintFonts f) {
  return pw.Text(
    'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
    style: f.text(7.5, color: _muted),
  );
}

pw.Widget _footer(pw.Context ctx, InvoicePrintSheet sheet, PrintFonts f) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.only(top: 6),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: _hairline, width: 0.5)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: <pw.Widget>[
        pw.Expanded(
          child: pw.Text(
            'Generated by PFA Pharmacy Invoice Tracker · ${formatDate(sheet.printedOn)}',
            style: f.text(7.5, color: _muted),
          ),
        ),
        _pageStamp(ctx, f),
      ],
    ),
  );
}

pw.Widget _amountInWords(InvoicePrintSheet sheet, PrintFonts f) {
  return _panel(
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        _label('Amount in words', f),
        pw.SizedBox(height: 3),
        pw.Text(
          sheet.totals.amountInWords,
          style: f.text(9.5, bold: false, color: _body),
        ),
      ],
    ),
    fill: _wash,
  );
}

/// One row of the money block. [rule] draws the line above the row, [heavy]
/// marks the total itself: only those two are bold, and only a total gets a
/// black line, so the eye lands on the figure that matters.
pw.Widget _moneyRow(
  String label,
  String amount,
  PrintFonts f, {
  bool rule = false,
  bool heavy = false,
  PdfColor color = _body,
}) {
  final style = f.text(
    heavy ? 12 : 9.5,
    bold: heavy,
    color: heavy ? _ink : color,
  );
  return pw.Container(
    width: double.infinity,
    padding: pw.EdgeInsets.symmetric(vertical: heavy ? 6 : 3.5),
    decoration: rule || heavy
        ? pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: heavy ? _ink : _rule, width: 0.8),
            ),
          )
        : null,
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: <pw.Widget>[
        pw.Expanded(child: pw.Text(label, style: style)),
        pw.Text(amount, style: style),
      ],
    ),
  );
}

pw.Widget _moneyBlock(InvoicePrintSheet sheet, PrintFonts f) {
  final t = sheet.totals;
  final rows = <pw.Widget>[
    _moneyRow(t.subtotalLabel, f.money(t.subtotal), f),
  ];
  if (t.hasTax) {
    rows.add(_moneyRow(t.taxLabel, f.money(t.tax), f));
  }
  rows.add(_moneyRow('TOTAL', f.money(t.total), f, heavy: true));

  if (t.paid > 0) {
    rows.add(_moneyRow('Paid', f.money(t.paid), f, rule: true));
    rows.add(_moneyRow(t.balanceLabel, f.money(t.balance), f, heavy: true));
  }

  return pw.Column(children: rows);
}

pw.Widget _signaturePair(PrintFonts f) {
  pw.Widget one(String role) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.SizedBox(height: 22),
          pw.Container(height: 0.6, color: _rule),
          pw.SizedBox(height: 3),
          pw.Text(role, style: f.text(8, color: _muted)),
        ],
      ),
    );
  }

  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: <pw.Widget>[
      one('Authorised signature'),
      pw.SizedBox(width: 24),
      one('Received by'),
    ],
  );
}

pw.Widget _businessName(InvoicePrintSheet sheet, PrintFonts f, {double size = 15}) {
  final name =
      sheet.businessName.isEmpty ? 'PFA Pharmacy' : sheet.businessName;
  return pw.Text(
    name.toUpperCase(),
    style: f.text(size, bold: true, spacing: 0.4),
  );
}

// ---------------------------------------------------------------------------
// Layout 1: classic form.
// ---------------------------------------------------------------------------

pw.MultiPage _classicFormPage(InvoicePrintSheet sheet, PrintFonts f) {
  return pw.MultiPage(
    pageFormat: _a4,
    margin: const pw.EdgeInsets.fromLTRB(_margin, _margin, _margin, _margin),
    header: (ctx) => ctx.pageNumber == 1
        ? _classicTop(sheet, f)
        : _classicContinuation(sheet, f),
    footer: (ctx) => _footer(ctx, sheet, f),
    build: (ctx) => <pw.Widget>[
      _classicDetails(sheet, f),
      pw.SizedBox(height: 14),
      _classicItems(sheet, f),
      pw.SizedBox(height: 12),
      _amountInWords(sheet, f),
      pw.SizedBox(height: 12),
      _classicBottom(sheet, f),
    ],
  );
}

pw.Widget _classicTop(InvoicePrintSheet sheet, PrintFonts f) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: <pw.Widget>[
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                _businessName(sheet, f),
                if (sheet.contactLine.isNotEmpty) ...<pw.Widget>[
                  pw.SizedBox(height: 3),
                  pw.Text(sheet.contactLine, style: f.text(8, color: _muted)),
                ],
              ],
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _ink, width: 1),
              borderRadius: pw.BorderRadius.circular(2),
            ),
            child: pw.Text(
              'INVOICE',
              style: f.text(13, bold: true, spacing: 1.6),
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 8),
      _thickRule(),
      pw.SizedBox(height: 10),
    ],
  );
}

/// Continuation pages keep the business line and repeat the column titles, so a
/// long invoice never runs into a page of numbers with no headings.
pw.Widget _classicContinuation(InvoicePrintSheet sheet, PrintFonts f) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: <pw.Widget>[
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          _businessName(sheet, f, size: 10),
          pw.Text(sheet.invoiceNumber, style: f.text(9, bold: true)),
        ],
      ),
      pw.SizedBox(height: 4),
      _thickRule(),
      pw.SizedBox(height: 8),
      _itemsHeaderRow(f),
      pw.SizedBox(height: 4),
    ],
  );
}

pw.Widget _classicDetails(InvoicePrintSheet sheet, PrintFonts f) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: <pw.Widget>[
      _panel(
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Expanded(
              flex: 3,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  _label('Bill to', f),
                  pw.SizedBox(height: 2),
                  _value(sheet.supplierName, f, size: 11),
                  for (final line in sheet.supplierLines) ...<pw.Widget>[
                    pw.SizedBox(height: 1.5),
                    pw.Text(line, style: f.text(8.5, bold: false, color: _muted)),
                  ],
                ],
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              flex: 2,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  _field('Status', sheet.status, f),
                  if (sheet.hasDescription)
                    _field('Description', sheet.description, f, size: 8.5),
                ],
              ),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 10),
      _grid(
        <List<String>>[
          <String>[
            'Invoice no',
            sheet.invoiceNumber,
            'Invoice date',
            sheet.invoiceDate,
            'Due date',
            sheet.dueDate,
          ],
          <String>[
            'Received',
            sheet.receivedDate,
            if (sheet.hasReference) 'Ref / PO',
            if (sheet.hasReference) sheet.reference,
            'Method',
            sheet.hasPaymentMethod ? sheet.paymentMethod : '—',
          ],
        ],
        f,
      ),
    ],
  );
}

pw.Widget _itemsHeaderRow(PrintFonts f) {
  pw.Widget cell(String label, {int flex = 1, bool right = true}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Text(
          label.toUpperCase(),
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
          style: f.text(7, bold: true, color: _muted, spacing: 0.6),
        ),
      ),
    );
  }

  return pw.Container(
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _rule, width: 0.7)),
    ),
    child: pw.Row(
      children: <pw.Widget>[
        pw.SizedBox(width: 18),
        cell('Item', flex: 5, right: false),
        cell('Boxes', flex: 2),
        cell('Pcs/box', flex: 2),
        cell('Price/box', flex: 3),
        cell('Line total', flex: 3),
      ],
    ),
  );
}

pw.Widget _classicItems(InvoicePrintSheet sheet, PrintFonts f) {
  if (!sheet.hasLines) {
    return _panel(
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          _label('Items', f),
          pw.SizedBox(height: 4),
          pw.Text(
            'No item breakdown was recorded for this invoice.',
            style: f.text(9, bold: false, color: _muted),
          ),
        ],
      ),
    );
  }

  return pw.Table(
    columnWidths: const <int, pw.TableColumnWidth>{
      0: pw.FixedColumnWidth(18),
      1: pw.FlexColumnWidth(5),
      2: pw.FlexColumnWidth(2),
      3: pw.FlexColumnWidth(2),
      4: pw.FlexColumnWidth(3),
      5: pw.FlexColumnWidth(3),
    },
    children: <pw.TableRow>[
      // The column titles live in the table so page one shows them, and in the
      // page header so every later page repeats them.
      pw.TableRow(children: <pw.Widget>[_itemsHeaderRow(f)]),
      for (var i = 0; i < sheet.lines.length; i++)
        pw.TableRow(
          children: <pw.Widget>[
            _itemCell('${i + 1}', f, muted: true),
            _itemCell(sheet.lines[i].name, f),
            _itemCell('${sheet.lines[i].boxes}', f, right: true),
            _itemCell('${sheet.lines[i].piecesPerBox}', f, right: true),
            _itemCell(f.money(sheet.lines[i].pricePerBox), f, right: true),
            _itemCell(f.money(sheet.lines[i].lineTotal), f, right: true),
          ],
        ),
    ],
  );
}

pw.Widget _itemCell(
  String text,
  PrintFonts f, {
  bool right = false,
  bool muted = false,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 2),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _hairline, width: 0.4)),
    ),
    child: pw.Text(
      text,
      textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
      style: f.text(9, color: muted ? _muted : _body),
    ),
  );
}

pw.Widget _classicBottom(InvoicePrintSheet sheet, PrintFonts f) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: <pw.Widget>[
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                if (sheet.hasNotes) ...<pw.Widget>[
                  _label('Notes', f),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    sheet.notes,
                    style: f.text(9, bold: false),
                  ),
                ],
                pw.SizedBox(height: 18),
                _signaturePair(f),
              ],
            ),
          ),
          pw.SizedBox(width: 18),
          pw.Expanded(flex: 2, child: _moneyBlock(sheet, f)),
        ],
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Layout 2: split ledger. Details live in a narrow left rail so product names
// get the wide side of the page.
// ---------------------------------------------------------------------------

pw.Page _splitLedgerPage(InvoicePrintSheet sheet, PrintFonts f) {
  // A two-column page cannot flow across a page break, so an invoice with a
  // long item list falls back to the same rail laid out as a top strip with
  // the items running full width underneath.
  if (sheet.lines.length > 24) {
    return _splitLedgerLongPage(sheet, f);
  }

  return pw.Page(
    pageFormat: _a4,
    margin: const pw.EdgeInsets.fromLTRB(_margin, _margin, _margin, _margin),
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        _splitTop(sheet, f),
        _hairlineRule(thickness: 1),
        pw.SizedBox(height: 12),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Expanded(flex: 2, child: _splitRail(sheet, f)),
            pw.SizedBox(width: 18),
            pw.Expanded(flex: 3, child: _splitItems(sheet, f)),
          ],
        ),
        pw.SizedBox(height: 14),
        _signaturePair(f),
        pw.Expanded(child: pw.SizedBox()),
        _footer(ctx, sheet, f),
      ],
    ),
  );
}

pw.MultiPage _splitLedgerLongPage(InvoicePrintSheet sheet, PrintFonts f) {
  return pw.MultiPage(
    pageFormat: _a4,
    margin: const pw.EdgeInsets.fromLTRB(_margin, _margin, _margin, _margin),
    header: (ctx) => ctx.pageNumber == 1
        ? _splitTop(sheet, f)
        : pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              _splitTop(sheet, f),
              _splitItemsHeader(f),
            ],
          ),
    footer: (ctx) => _footer(ctx, sheet, f),
    build: (ctx) => <pw.Widget>[
      _grid(
        <List<String>>[
          <String>[
            'Invoice no',
            sheet.invoiceNumber,
            'Invoice date',
            sheet.invoiceDate,
            'Due date',
            sheet.dueDate,
          ],
          <String>[
            'Received',
            sheet.receivedDate,
            'Supplier',
            sheet.supplierName,
            'Status',
            sheet.status,
          ],
        ],
        f,
      ),
      pw.SizedBox(height: 12),
      // Only the rows here: this variant puts the amount in words and the
      // money block after the list so they can start a fresh page.
      _splitItems(sheet, f, withTotals: false),
      pw.SizedBox(height: 12),
      _amountInWords(sheet, f),
      pw.SizedBox(height: 12),
      _moneyBlock(sheet, f),
      pw.SizedBox(height: 20),
      _signaturePair(f),
    ],
  );
}

pw.Widget _splitTop(InvoicePrintSheet sheet, PrintFonts f) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: <pw.Widget>[
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                _businessName(sheet, f, size: 13),
                if (sheet.contactLine.isNotEmpty) ...<pw.Widget>[
                  pw.SizedBox(height: 2),
                  pw.Text(sheet.contactLine, style: f.text(7.5, color: _muted)),
                ],
              ],
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: <pw.Widget>[
              pw.Text(
                'INVOICE LEDGER',
                style: f.text(10, bold: true, spacing: 1.4),
              ),
              pw.SizedBox(height: 2),
              pw.Text(sheet.invoiceNumber, style: f.text(12, bold: true)),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 8),
    ],
  );
}

pw.Widget _splitRail(InvoicePrintSheet sheet, PrintFonts f) {
  return _panel(
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        _label('Supplier', f),
        pw.SizedBox(height: 2),
        _value(sheet.supplierName, f, size: 10.5),
        for (final line in sheet.supplierLines) ...<pw.Widget>[
          pw.SizedBox(height: 1.5),
          pw.Text(line, style: f.text(8, bold: false, color: _muted)),
        ],
        pw.SizedBox(height: 12),
        _hairlineRule(),
        pw.SizedBox(height: 10),
        _field('Invoice date', sheet.invoiceDate, f, size: 9.5),
        pw.SizedBox(height: 8),
        _field('Due date', sheet.dueDate, f, size: 9.5),
        pw.SizedBox(height: 8),
        _field('Received', sheet.receivedDate, f, size: 9.5),
        if (sheet.hasReference) ...<pw.Widget>[
          pw.SizedBox(height: 8),
          _field('Ref / PO', sheet.reference, f, size: 9.5),
        ],
        pw.SizedBox(height: 8),
        _field('Status', sheet.status, f, size: 9.5),
        if (sheet.hasPaymentMethod) ...<pw.Widget>[
          pw.SizedBox(height: 8),
          _field('Method', sheet.paymentMethod, f, size: 9.5),
        ],
        if (sheet.paidDate != null) ...<pw.Widget>[
          pw.SizedBox(height: 8),
          _field('Paid on', sheet.paidDate!, f, size: 9.5),
        ],
        if (sheet.hasDescription) ...<pw.Widget>[
          pw.SizedBox(height: 10),
          _hairlineRule(),
          pw.SizedBox(height: 8),
          _field('Description', sheet.description, f, size: 8.5),
        ],
        if (sheet.hasNotes) ...<pw.Widget>[
          pw.SizedBox(height: 10),
          _hairlineRule(),
          pw.SizedBox(height: 8),
          _field('Notes', sheet.notes, f, size: 8.5),
        ],
      ],
    ),
    fill: _wash,
  );
}

pw.Widget _splitItemsHeader(PrintFonts f) {
  pw.Widget cell(String label, {int flex = 1, bool right = true}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Text(
          label.toUpperCase(),
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
          style: f.text(6.8, bold: true, color: _muted, spacing: 0.5),
        ),
      ),
    );
  }

  return pw.Container(
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _rule, width: 0.7)),
    ),
    child: pw.Row(
      children: <pw.Widget>[
        cell('Item', flex: 5, right: false),
        cell('Qty', flex: 2),
        cell('Price/box', flex: 3),
        cell('Line total', flex: 3),
      ],
    ),
  );
}

pw.Widget _splitItems(
  InvoicePrintSheet sheet,
  PrintFonts f, {
  bool withTotals = true,
}) {
  if (!sheet.hasLines) {
    return _panel(
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          _label('Items', f),
          pw.SizedBox(height: 4),
          pw.Text(
            'No item breakdown was recorded for this invoice.',
            style: f.text(8.5, bold: false, color: _muted),
          ),
        ],
      ),
    );
  }

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: <pw.Widget>[
      _splitItemsHeader(f),
      for (final line in sheet.lines)
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 4.5, horizontal: 2),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _hairline, width: 0.4)),
          ),
          child: pw.Row(
            children: <pw.Widget>[
              pw.Expanded(
                flex: 5,
                child: pw.Text(line.name, style: f.text(8.8)),
              ),
              pw.Expanded(
                flex: 2,
                child: pw.Text(
                  line.quantityLabel,
                  textAlign: pw.TextAlign.right,
                  style: f.text(8.2, color: _muted),
                ),
              ),
              pw.Expanded(
                flex: 3,
                child: pw.Text(
                  f.money(line.pricePerBox),
                  textAlign: pw.TextAlign.right,
                  style: f.text(8.5, color: _muted),
                ),
              ),
              pw.Expanded(
                flex: 3,
                child: pw.Text(
                  f.money(line.lineTotal),
                  textAlign: pw.TextAlign.right,
                  style: f.text(8.8),
                ),
              ),
            ],
          ),
        ),
      if (withTotals) ...<pw.Widget>[
        pw.SizedBox(height: 8),
        _amountInWords(sheet, f),
        pw.SizedBox(height: 8),
        _moneyBlock(sheet, f),
      ],
    ],
  );
}

// ---------------------------------------------------------------------------
// Layout 3: payment voucher. The copy you hand to the supplier, so the amount
// paid leads and the balance afterwards closes the document.
// ---------------------------------------------------------------------------

/// A voucher is a summary, not a statement: a very long item list is trimmed so
/// the document always stays on one page.
const int _voucherMaxLines = 12;

pw.Page _paymentVoucherPage(InvoicePrintSheet sheet, PrintFonts f) {
  final lines = sheet.lines.length > _voucherMaxLines
      ? sheet.lines.sublist(0, _voucherMaxLines)
      : sheet.lines;
  final hidden = sheet.lines.length - lines.length;

  return pw.Page(
    pageFormat: _a4,
    margin: const pw.EdgeInsets.fromLTRB(_margin, _margin, _margin, _margin),
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _rule, width: 0.8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: <pw.Widget>[
              _businessName(sheet, f, size: 16),
              if (sheet.contactLine.isNotEmpty) ...<pw.Widget>[
                pw.SizedBox(height: 3),
                pw.Text(
                  sheet.contactLine,
                  textAlign: pw.TextAlign.center,
                  style: f.text(8, color: _muted),
                ),
              ],
              pw.SizedBox(height: 8),
              pw.Text(
                'PAYMENT ADVICE',
                style: f.text(10, bold: true, spacing: 2.2),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'SUPPLIER COPY',
                style: f.text(7.5, color: _muted, spacing: 1.4),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 14),
        _voucherParties(sheet, f),
        pw.SizedBox(height: 14),
        _voucherFigure(sheet, f),
        pw.SizedBox(height: 14),
        _label('Settles the following items', f),
        pw.SizedBox(height: 4),
        _voucherItems(lines, hidden, f),
        pw.SizedBox(height: 12),
        _voucherMeta(sheet, f),
        pw.Expanded(child: pw.SizedBox()),
        _signaturePair(f),
        pw.SizedBox(height: 14),
        _footer(ctx, sheet, f),
      ],
    ),
  );
}

pw.Widget _voucherParties(InvoicePrintSheet sheet, PrintFonts f) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: <pw.Widget>[
      pw.Expanded(
        flex: 3,
        child: _panel(
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              _label('To', f),
              pw.SizedBox(height: 2),
              _value(sheet.supplierName, f, size: 10.5),
              for (final line in sheet.supplierLines) ...<pw.Widget>[
                pw.SizedBox(height: 1.5),
                pw.Text(line, style: f.text(8.5, bold: false, color: _muted)),
              ],
            ],
          ),
        ),
      ),
      pw.SizedBox(width: 12),
      pw.Expanded(
        flex: 2,
        child: _panel(
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              _field('Against invoice', sheet.invoiceNumber, f, size: 10),
              pw.SizedBox(height: 6),
              _field('Invoice total', f.money(sheet.totals.total), f, size: 10),
            ],
          ),
          fill: _wash,
        ),
      ),
    ],
  );
}

pw.Widget _voucherFigure(InvoicePrintSheet sheet, PrintFonts f) {
  final t = sheet.totals;
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(vertical: 14, horizontal: 14),
    decoration: pw.BoxDecoration(
      color: _wash,
      border: pw.Border.all(color: _rule, width: 0.8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Text(
          'AMOUNT PAID',
          style: f.text(8, bold: true, spacing: 1.6),
        ),
        pw.SizedBox(height: 4),
        pw.Text(f.money(t.paid), style: f.text(26, bold: true)),
        pw.SizedBox(height: 5),
        pw.Text(t.amountInWords, style: f.text(8.5, bold: false, color: _muted)),
        pw.SizedBox(height: 8),
        _hairlineRule(thickness: 0.8, color: _rule),
        pw.SizedBox(height: 7),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: <pw.Widget>[
            _value(
              t.isSettled ? 'Balance settled in full' : 'Balance outstanding',
              f,
              size: 9.5,
            ),
            _value(f.money(t.balance), f, size: 11),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _voucherItems(
  List<InvoicePrintLine> lines,
  int hidden,
  PrintFonts f,
) {
  if (lines.isEmpty) {
    return _panel(
      pw.Text(
        'This invoice was recorded without an item breakdown.',
        style: f.text(9, bold: false, color: _muted),
      ),
    );
  }

  return pw.Table(
    columnWidths: const <int, pw.TableColumnWidth>{
      0: pw.FlexColumnWidth(6),
      1: pw.FlexColumnWidth(2),
      2: pw.FlexColumnWidth(3),
    },
    children: <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _rule, width: 0.7)),
        ),
        children: <pw.Widget>[
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
            child: pw.Text(
              'ITEM',
              style: f.text(7, bold: true, color: _muted, spacing: 0.6),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
            child: pw.Text(
              'QTY',
              textAlign: pw.TextAlign.right,
              style: f.text(7, bold: true, color: _muted, spacing: 0.6),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
            child: pw.Text(
              'AMOUNT',
              textAlign: pw.TextAlign.right,
              style: f.text(7, bold: true, color: _muted, spacing: 0.6),
            ),
          ),
        ],
      ),
      for (final line in lines)
        pw.TableRow(
          children: <pw.Widget>[
            _itemCell(line.name, f),
            _itemCell(line.quantityLabel, f, right: true, muted: true),
            _itemCell(f.money(line.lineTotal), f, right: true),
          ],
        ),
      if (hidden > 0)
        pw.TableRow(
          children: <pw.Widget>[
            _itemCell('+ $hidden more items on the full invoice', f, muted: true),
            _itemCell('', f),
            _itemCell('', f),
          ],
        ),
    ],
  );
}

pw.Widget _voucherMeta(InvoicePrintSheet sheet, PrintFonts f) {
  return _panel(
    _grid(
      <List<String>>[
        <String>[
          'Method',
          sheet.hasPaymentMethod ? sheet.paymentMethod : '—',
          'Date',
          sheet.paidDate ?? sheet.receivedDate,
          'Status',
          sheet.status,
        ],
      ],
      f,
      columns: 3,
      fieldSize: 9.5,
    ),
    fill: _wash,
  );
}
