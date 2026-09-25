import 'supplier_invoice.dart';

/// One slice of a payment, applied to a single invoice. A single payment can
/// carry several slices so one bank transfer settles several invoices at once.
class PaymentAllocation {
  const PaymentAllocation({
    required this.invoiceId,
    required this.amountPesewas,
  });

  final String invoiceId;
  final int amountPesewas;

  PaymentAllocation copyWith({int? amountPesewas}) => PaymentAllocation(
        invoiceId: invoiceId,
        amountPesewas: amountPesewas ?? this.amountPesewas,
      );

  Map<String, dynamic> toJson() => {
        'invoiceId': invoiceId,
        'amountPesewas': amountPesewas,
      };

  factory PaymentAllocation.fromJson(Map<String, dynamic> json) =>
      PaymentAllocation(
        invoiceId: json['invoiceId'] as String,
        amountPesewas: (json['amountPesewas'] as int?) ?? 0,
      );
}

/// A payment made to a supplier: when it happened, how it was made, and which
/// invoices it settled.
class Payment {
  Payment({
    String? id,
    required this.date,
    this.method = 'Cash',
    this.reference = '',
    this.notes = '',
    this.isLegacy = false,
    List<PaymentAllocation> allocations = const <PaymentAllocation>[],
  }) : id = id ?? 'pay_${DateTime.now().microsecondsSinceEpoch}',
       allocations = List.unmodifiable(allocations);

  final String id;
  final DateTime date;
  final String method;
  final String reference;
  final String notes;

  /// True when this record was created from an invoice's hand-typed paid
  /// amount during the upgrade, so the UI can label it as an opening balance.
  final bool isLegacy;
  final List<PaymentAllocation> allocations;

  int get amountPesewas =>
      allocations.fold(0, (sum, a) => sum + a.amountPesewas);

  bool get isEmpty => allocations.isEmpty;

  Set<String> get invoiceIds =>
      allocations.map((a) => a.invoiceId).toSet();

  Payment copyWith({
    DateTime? date,
    String? method,
    String? reference,
    String? notes,
    List<PaymentAllocation>? allocations,
  }) =>
      Payment(
        id: id,
        date: date ?? this.date,
        method: method ?? this.method,
        reference: reference ?? this.reference,
        notes: notes ?? this.notes,
        isLegacy: isLegacy,
        allocations: allocations ?? this.allocations,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'method': method,
        'reference': reference,
        'notes': notes,
        'isLegacy': isLegacy,
        'allocations': allocations.map((a) => a.toJson()).toList(),
      };

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        method: (json['method'] as String?) ?? 'Cash',
        reference: (json['reference'] as String?) ?? '',
        notes: (json['notes'] as String?) ?? '',
        isLegacy: (json['isLegacy'] as bool?) ?? false,
        allocations: ((json['allocations'] as List?) ?? const [])
            .map((e) => PaymentAllocation.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// How much each invoice has been paid, according to the payment records.
Map<String, int> paidTotalsByInvoice(List<Payment> payments) {
  final totals = <String, int>{};
  for (final p in payments) {
    for (final a in p.allocations) {
      totals[a.invoiceId] = (totals[a.invoiceId] ?? 0) + a.amountPesewas;
    }
  }
  return totals;
}

/// Payment records for any invoice whose hand-typed paid amount is not yet
/// explained by an existing record. Runs on every load, so an invoice that was
/// marked paid by hand after the upgrade still gains a record, and an invoice
/// that is already covered gains nothing.
List<Payment> legacyPaymentsFor(
  List<SupplierInvoice> invoices,
  List<Payment> existing,
) {
  final covered = paidTotalsByInvoice(existing);
  final seeded = <Payment>[];
  for (final inv in invoices) {
    if (inv.amountPaidPesewas <= 0) continue;
    final missing = inv.amountPaidPesewas - (covered[inv.id] ?? 0);
    if (missing <= 0) continue;
    seeded.add(
      Payment(
        date: inv.paidDate ?? inv.receivedDate,
        method: inv.paymentMethod,
        notes: 'Opening balance carried over from the invoice.',
        isLegacy: true,
        allocations: <PaymentAllocation>[
          PaymentAllocation(
            invoiceId: inv.id,
            amountPesewas: missing,
          ),
        ],
      ),
    );
  }
  return seeded;
}
