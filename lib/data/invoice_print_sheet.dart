import '../core/format.dart';
import '../models/business_profile.dart';
import '../models/supplier.dart';
import '../models/supplier_invoice.dart';

/// One row of the printed item table.
class InvoicePrintLine {
  const InvoicePrintLine({
    required this.name,
    required this.boxes,
    required this.piecesPerBox,
    required this.pricePerBox,
    required this.lineTotal,
  });

  final String name;
  final int boxes;
  final int piecesPerBox;
  final int pricePerBox;
  final int lineTotal;

  /// "5 box × 20", matching how the app shows quantity elsewhere.
  String get quantityLabel => '$boxes box × $piecesPerBox';
}

/// The money block, shared by all three layouts.
class InvoicePrintTotals {
  const InvoicePrintTotals({
    required this.subtotalLabel,
    required this.subtotal,
    required this.taxLabel,
    required this.tax,
    required this.total,
    required this.paid,
    required this.balanceLabel,
    required this.balance,
    required this.amountInWords,
  });

  final String subtotalLabel;
  final int subtotal;
  final String taxLabel;
  final int tax;
  final int total;
  final int paid;
  final String balanceLabel;
  final int balance;
  final String amountInWords;

  bool get isSettled => balance <= 0;
  bool get hasTax => tax > 0;
}

/// Everything the three layouts need, worked out once so the renderers stay
/// dumb and the numbers are testable without touching a PDF.
class InvoicePrintSheet {
  const InvoicePrintSheet({
    required this.businessName,
    required this.contactLine,
    required this.supplierName,
    required this.supplierLines,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.dueDate,
    required this.receivedDate,
    required this.paidDate,
    required this.reference,
    required this.description,
    required this.status,
    required this.paymentMethod,
    required this.lines,
    required this.totals,
    required this.notes,
    required this.printedOn,
  });

  final String businessName;
  final String contactLine;
  final String supplierName;

  /// Location and phone, one per line, under the supplier name.
  final List<String> supplierLines;

  final String invoiceNumber;
  final String invoiceDate;
  final String dueDate;
  final String receivedDate;

  /// Null when nothing has been paid yet, so the row is left off the page.
  final String? paidDate;

  final String reference;
  final String description;
  final String status;
  final String paymentMethod;
  final List<InvoicePrintLine> lines;
  final InvoicePrintTotals totals;
  final String notes;
  final DateTime printedOn;

  bool get hasReference => reference.trim().isNotEmpty;
  bool get hasDescription => description.trim().isNotEmpty;
  bool get hasNotes => notes.trim().isNotEmpty;
  bool get hasPaymentMethod => paymentMethod.trim().isNotEmpty;
  bool get hasLines => lines.isNotEmpty;
}

/// Builds the sheet from the stored invoice. [printedOn] is passed in rather
/// than read from the clock so the output is reproducible in tests.
InvoicePrintSheet buildInvoicePrintSheet(
  SupplierInvoice invoice, {
  Supplier? supplier,
  BusinessProfile? profile,
  DateTime? printedOn,
}) {
  final now = printedOn ?? DateTime.now();
  final business = profile ?? BusinessProfile();

  final supplierName =
      supplier?.name.trim().isNotEmpty == true ? supplier!.name : 'Unknown supplier';
  final supplierLines = <String>[
    if (supplier != null && supplier.location.trim().isNotEmpty)
      supplier.location.trim(),
    if (supplier != null && supplier.phone.trim().isNotEmpty)
      supplier.phone.trim(),
  ];

  // The printed money block is built from the invoice's own getters so a
  // printed page can never disagree with the total shown on screen. The item
  // lines are the breakdown of that figure, not a second source of truth.
  final subtotal = invoice.amountPesewas;
  final tax = invoice.taxPesewas;
  final total = invoice.totalPesewas;
  final paid = invoice.amountPaidPesewas;
  final balance = invoice.balancePesewas;

  return InvoicePrintSheet(
    businessName: business.name.trim(),
    contactLine: business.contactLine,
    supplierName: supplierName,
    supplierLines: supplierLines,
    invoiceNumber: invoice.invoiceNumber,
    invoiceDate: formatDate(invoice.invoiceDate),
    dueDate: formatDate(invoice.dueDate),
    receivedDate: formatDate(invoice.receivedDate),
    paidDate: invoice.paidDate == null ? null : formatDate(invoice.paidDate!),
    reference: invoice.reference.trim(),
    description: invoice.description.trim(),
    status: invoice.statusAt(now).label,
    paymentMethod: invoice.paymentMethod.trim(),
    lines: <InvoicePrintLine>[
      for (final line in invoice.lines)
        InvoicePrintLine(
          name: line.name,
          boxes: line.boxes,
          piecesPerBox: line.piecesPerBox,
          pricePerBox: line.pricePerBoxPesewas,
          lineTotal: line.totalPesewas,
        ),
    ],
    totals: InvoicePrintTotals(
      subtotalLabel: invoice.lines.isNotEmpty ? 'Subtotal' : 'Amount',
      subtotal: subtotal,
      taxLabel: 'VAT (${_trimRate(invoice.taxRatePercent)}%)',
      tax: tax,
      total: total,
      paid: paid,
      balanceLabel: balance <= 0 ? 'Balance settled' : 'Balance due',
      balance: balance,
      amountInWords: moneyInWords(total),
    ),
    notes: invoice.notes.trim(),
    printedOn: now,
  );
}

/// Whole numbers print without a trailing ".0" so "VAT (15%)" does not become
/// "VAT (15.0%)".
String _trimRate(double rate) {
  final rounded = rate.round();
  return rate == rounded ? '$rounded' : '$rate';
}
