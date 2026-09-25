const List<String> kPaymentMethods = [
  'Cash',
  'Bank Pay',
  'Cheque',
  'MoMo',
  'Card',
];

enum InvoiceStatus {
  paid('Paid'),
  overdue('Overdue'),
  partiallyPaid('Partially Paid'),
  open('Open');

  const InvoiceStatus(this.label);

  final String label;
}

/// A single product line on an invoice.
///
/// In wholesale, medicines arrive in boxes. Each line records how many boxes
/// were bought, how many items are inside each box, and the price per box.
/// Loose (unboxed) items are entered as 1 item per box with the unit price.
class InvoiceLine {
  InvoiceLine({
    required this.name,
    this.boxes = 1,
    this.piecesPerBox = 1,
    required this.pricePerBoxPesewas,
  });

  factory InvoiceLine.fromJson(Map<String, dynamic> json) {
    return InvoiceLine(
      name: (json['name'] as String?) ?? '',
      boxes: (json['boxes'] as int?) ?? 1,
      piecesPerBox: (json['piecesPerBox'] as int?) ?? 1,
      pricePerBoxPesewas: (json['pricePerBoxPesewas'] as int?) ?? 0,
    );
  }

  final String name;
  final int boxes;
  final int piecesPerBox;
  final int pricePerBoxPesewas;

  /// Total number of items bought (boxes multiplied by items per box).
  int get pieceCount => boxes * piecesPerBox;

  /// Cost of this line (boxes multiplied by price per box).
  int get totalPesewas => boxes * pricePerBoxPesewas;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'boxes': boxes,
      'piecesPerBox': piecesPerBox,
      'pricePerBoxPesewas': pricePerBoxPesewas,
    };
  }
}

class SupplierInvoice {
  SupplierInvoice({
    required this.id,
    required this.supplierId,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.receivedDate,
    required this.dueDate,
    required this.amountPesewas,
    this.taxRatePercent = 0,
    this.amountPaidPesewas = 0,
    this.reference = '',
    this.description = '',
    this.paidDate,
    this.paymentMethod = 'Cash',
    this.notes = '',
    this.receipts = const [],
    this.lines = const [],
  });

  factory SupplierInvoice.create({
    required String supplierId,
    required String invoiceNumber,
    required DateTime invoiceDate,
    required DateTime receivedDate,
    required DateTime dueDate,
    required int amountPesewas,
    double taxRatePercent = 0,
    int amountPaidPesewas = 0,
    String reference = '',
    String description = '',
    DateTime? paidDate,
    String paymentMethod = 'Cash',
    String notes = '',
    List<String> receipts = const [],
    List<InvoiceLine> lines = const [],
  }) {
    return SupplierInvoice(
      id: 'i_${DateTime.now().microsecondsSinceEpoch}',
      supplierId: supplierId,
      invoiceNumber: invoiceNumber,
      invoiceDate: invoiceDate,
      receivedDate: receivedDate,
      dueDate: dueDate,
      amountPesewas: amountPesewas,
      taxRatePercent: taxRatePercent,
      amountPaidPesewas: amountPaidPesewas,
      reference: reference,
      description: description,
      paidDate: paidDate,
      paymentMethod: paymentMethod,
      notes: notes,
      receipts: receipts,
      lines: lines,
    );
  }

  final String id;
  final String supplierId;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final DateTime receivedDate;
  final DateTime dueDate;
  final int amountPesewas;
  final double taxRatePercent;
  final int amountPaidPesewas;
  final String reference;
  final String description;
  final DateTime? paidDate;
  final String paymentMethod;
  final String notes;
  final List<String> receipts;
  final List<InvoiceLine> lines;

  int get taxPesewas => (amountPesewas * taxRatePercent / 100).round();
  int get totalPesewas => amountPesewas + taxPesewas;
  int get balancePesewas => totalPesewas - amountPaidPesewas;
  bool get owesMoney => balancePesewas > 0;

  /// Sum of all product line totals (0 when the invoice has no lines).
  int get lineItemsTotalPesewas =>
      lines.fold(0, (sum, l) => sum + l.totalPesewas);

  InvoiceStatus statusAt(DateTime now) {
    if (balancePesewas <= 0) return InvoiceStatus.paid;
    if (dueDate.isBefore(now) && !_isSameDay(dueDate, now)) {
      return InvoiceStatus.overdue;
    }
    if (amountPaidPesewas > 0) return InvoiceStatus.partiallyPaid;
    return InvoiceStatus.open;
  }

  String get statusLabel => statusAt(DateTime.now()).label;

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  SupplierInvoice copyWith({
    String? supplierId,
    String? invoiceNumber,
    DateTime? invoiceDate,
    DateTime? receivedDate,
    DateTime? dueDate,
    int? amountPesewas,
    double? taxRatePercent,
    int? amountPaidPesewas,
    DateTime? paidDate,
    bool clearPaidDate = false,
    String? reference,
    String? description,
    String? paymentMethod,
    String? notes,
    List<String>? receipts,
    List<InvoiceLine>? lines,
  }) {
    return SupplierInvoice(
      id: id,
      supplierId: supplierId ?? this.supplierId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      receivedDate: receivedDate ?? this.receivedDate,
      dueDate: dueDate ?? this.dueDate,
      amountPesewas: amountPesewas ?? this.amountPesewas,
      taxRatePercent: taxRatePercent ?? this.taxRatePercent,
      amountPaidPesewas: amountPaidPesewas ?? this.amountPaidPesewas,
      paidDate: clearPaidDate ? null : (paidDate ?? this.paidDate),
      reference: reference ?? this.reference,
      description: description ?? this.description,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      receipts: receipts ?? this.receipts,
      lines: lines ?? this.lines,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'supplierId': supplierId,
      'invoiceNumber': invoiceNumber,
      'invoiceDate': invoiceDate.toIso8601String(),
      'receivedDate': receivedDate.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'amountPesewas': amountPesewas,
      'taxRatePercent': taxRatePercent,
      'amountPaidPesewas': amountPaidPesewas,
      'reference': reference,
      'description': description,
      'paidDate': paidDate?.toIso8601String(),
      'paymentMethod': paymentMethod,
'notes': notes,
        'receipts': receipts,
        'lines': lines.map((l) => l.toJson()).toList(),
      };
    }

  factory SupplierInvoice.fromJson(Map<String, dynamic> json) {
    return SupplierInvoice(
      id: json['id'] as String,
      supplierId: json['supplierId'] as String,
      invoiceNumber: json['invoiceNumber'] as String,
      invoiceDate:
          DateTime.parse(json['invoiceDate'] as String),
      receivedDate:
          DateTime.parse(json['receivedDate'] as String),
      dueDate: DateTime.parse(json['dueDate'] as String),
      amountPesewas: json['amountPesewas'] as int,
      taxRatePercent: ((json['taxRatePercent'] as num?) ?? 0).toDouble(),
      amountPaidPesewas: (json['amountPaidPesewas'] as int?) ?? 0,
      reference: (json['reference'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      paidDate: json['paidDate'] == null
          ? null
          : DateTime.parse(json['paidDate'] as String),
      paymentMethod: (json['paymentMethod'] as String?) ?? 'Cash',
      notes: (json['notes'] as String?) ?? '',
      receipts: ((json['receipts'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(),
      lines: ((json['lines'] as List?) ?? const [])
          .map((e) => InvoiceLine.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}