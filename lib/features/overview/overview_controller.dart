import '../../models/payment.dart';
import '../../models/supplier.dart';
import '../../models/supplier_invoice.dart';

/// The figures the overview page leads with, worked out once so the page does
/// not have to walk the ledger five times over.
class LedgerSummary {
  const LedgerSummary({
    required this.outstanding,
    required this.overdue,
    required this.overdueCount,
    required this.openCount,
    required this.invoicedTotal,
    required this.paidTotal,
    required this.paidThisMonth,
    required this.invoicedThisMonth,
    required this.invoiceCount,
    required this.paymentCount,
    required this.supplierCount,
    required this.productCount,
    required this.settledCount,
  });

  final int outstanding;
  final int overdue;
  final int overdueCount;
  final int openCount;
  final int invoicedTotal;
  final int paidTotal;
  final int paidThisMonth;
  final int invoicedThisMonth;
  final int invoiceCount;
  final int paymentCount;
  final int supplierCount;
  final int productCount;
  final int settledCount;

  /// The share of everything bought that is still owed, as a fraction.
  double get outstandingShare {
    if (invoicedTotal <= 0) return 0;
    return (outstanding / invoicedTotal).clamp(0.0, 1.0);
  }

  bool get isEmpty =>
      invoiceCount == 0 && supplierCount == 0 && paymentCount == 0;
}

/// One month of the trend chart: what was bought and what was paid.
class MonthPoint {
  const MonthPoint({
    required this.month,
    required this.invoiced,
    required this.paid,
  });

  final DateTime month;
  final int invoiced;
  final int paid;
}

/// How much one supplier is owed, and how much business it accounts for.
class SupplierShare {
  const SupplierShare({
    required this.supplier,
    required this.outstanding,
    required this.invoiceCount,
  });

  final Supplier supplier;
  final int outstanding;
  final int invoiceCount;
}

/// A month the window has not reached yet still gets a point, so the chart
/// keeps an even rhythm instead of stopping short.
DateTime _monthStart(DateTime date) => DateTime(date.year, date.month);

LedgerSummary summarise({
  required List<SupplierInvoice> invoices,
  required List<Payment> payments,
  required int supplierCount,
  required int productCount,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  var outstanding = 0;
  var overdue = 0;
  var overdueCount = 0;
  var openCount = 0;
  var invoicedTotal = 0;
  var paidTotal = 0;
  var settledCount = 0;
  var invoicedThisMonth = 0;

  for (final inv in invoices) {
    invoicedTotal += inv.totalPesewas;
    paidTotal += inv.amountPaidPesewas;
    // Counted before the balance check, so an invoice bought this month counts
    // even when it has already been settled in full.
    if (_monthStart(inv.invoiceDate) == _monthStart(today)) {
      invoicedThisMonth += inv.totalPesewas;
    }
    final balance = inv.balancePesewas;
    final status = inv.statusAt(today);
    if (status == InvoiceStatus.paid) settledCount++;
    if (balance <= 0) continue;
    openCount++;
    outstanding += balance;
    if (status == InvoiceStatus.overdue) {
      overdue += balance;
      overdueCount++;
    }
  }

  var paidThisMonth = 0;
  for (final p in payments) {
    if (_monthStart(p.date) == _monthStart(today)) {
      paidThisMonth += p.amountPesewas;
    }
  }

  return LedgerSummary(
    outstanding: outstanding,
    overdue: overdue,
    overdueCount: overdueCount,
    openCount: openCount,
    invoicedTotal: invoicedTotal,
    paidTotal: paidTotal,
    paidThisMonth: paidThisMonth,
    invoicedThisMonth: invoicedThisMonth,
    invoiceCount: invoices.length,
    paymentCount: payments.length,
    supplierCount: supplierCount,
    productCount: productCount,
    settledCount: settledCount,
  );
}

/// The last [months] months, oldest first, ending with the current one.
List<MonthPoint> monthlyTrend({
  required List<SupplierInvoice> invoices,
  required List<Payment> payments,
  int months = 6,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final first = DateTime(today.year, today.month - (months - 1));

  final invoiced = <int, int>{};
  final paid = <int, int>{};
  for (var i = 0; i < months; i++) {
    final key = first.year * 12 + first.month + i;
    invoiced[key] = 0;
    paid[key] = 0;
  }

  for (final inv in invoices) {
    final key = inv.invoiceDate.year * 12 + inv.invoiceDate.month;
    if (invoiced.containsKey(key)) {
      invoiced[key] = invoiced[key]! + inv.totalPesewas;
    }
  }
  for (final p in payments) {
    final key = p.date.year * 12 + p.date.month;
    if (paid.containsKey(key)) paid[key] = paid[key]! + p.amountPesewas;
  }

  return <MonthPoint>[
    for (var i = 0; i < months; i++)
      MonthPoint(
        month: DateTime(first.year, first.month + i),
        invoiced: invoiced[first.year * 12 + first.month + i] ?? 0,
        paid: paid[first.year * 12 + first.month + i] ?? 0,
      ),
  ];
}

/// Who the money is owed to, biggest first.
List<SupplierShare> supplierShares({
  required List<SupplierInvoice> invoices,
  required List<Supplier> suppliers,
  DateTime? now,
  int limit = 6,
}) {
  final today = now ?? DateTime.now();
  final owed = <String, int>{};
  final counts = <String, int>{};
  for (final inv in invoices) {
    counts[inv.supplierId] = (counts[inv.supplierId] ?? 0) + 1;
    if (inv.balancePesewas <= 0) continue;
    owed[inv.supplierId] = (owed[inv.supplierId] ?? 0) + inv.balancePesewas;
  }
  final shares = <SupplierShare>[
    for (final s in suppliers)
      if ((owed[s.id] ?? 0) > 0 || counts.containsKey(s.id))
        SupplierShare(
          supplier: s,
          outstanding: owed[s.id] ?? 0,
          invoiceCount: counts[s.id] ?? 0,
        ),
  ]..sort((a, b) {
      final byOwed = b.outstanding.compareTo(a.outstanding);
      if (byOwed != 0) return byOwed;
      return b.invoiceCount.compareTo(a.invoiceCount);
    });
  return shares.take(limit).toList();
}

/// The invoices worth chasing: past their date, biggest balance first.
List<SupplierInvoice> needsAttention({
  required List<SupplierInvoice> invoices,
  DateTime? now,
  int limit = 5,
}) {
  final today = now ?? DateTime.now();
  final late = invoices
      .where((i) => i.statusAt(today) == InvoiceStatus.overdue)
      .toList()
    ..sort((a, b) => b.balancePesewas.compareTo(a.balancePesewas));
  return late.take(limit).toList();
}

/// How many days past the due date an invoice is, for the attention list.
int daysLate(SupplierInvoice invoice, DateTime now) {
  final due = DateTime(
    invoice.dueDate.year,
    invoice.dueDate.month,
    invoice.dueDate.day,
  );
  final today = DateTime(now.year, now.month, now.day);
  return today.difference(due).inDays;
}
