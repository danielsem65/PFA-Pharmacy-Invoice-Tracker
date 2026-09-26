import 'package:flutter_test/flutter_test.dart';
import 'package:pfa_pharmacy_invoice_tracker/features/overview/overview_controller.dart';
import 'package:pfa_pharmacy_invoice_tracker/models/payment.dart';
import 'package:pfa_pharmacy_invoice_tracker/models/supplier.dart';
import 'package:pfa_pharmacy_invoice_tracker/models/supplier_invoice.dart';

import 'helpers.dart';

void main() {
  final now = DateTime(2026, 3, 20);

  Payment payment(String id, DateTime date, int amount, String invoiceId) =>
      Payment(
        id: id,
        date: date,
        allocations: <PaymentAllocation>[
          PaymentAllocation(invoiceId: invoiceId, amountPesewas: amount),
        ],
      );

  group('summarise', () {
    test('adds up what is owed, what is late and what has been paid', () {
      final invoices = <SupplierInvoice>[
        invoice(
          id: 'open',
          amountPesewas: 50000,
          dueDate: DateTime(2026, 4, 1),
          invoiceDate: DateTime(2026, 3, 1),
        ),
        invoice(
          id: 'late',
          amountPesewas: 30000,
          dueDate: DateTime(2026, 3, 1),
          invoiceDate: DateTime(2026, 2, 1),
        ),
        invoice(
          id: 'part',
          amountPesewas: 40000,
          amountPaidPesewas: 15000,
          dueDate: DateTime(2026, 4, 5),
          invoiceDate: DateTime(2026, 3, 5),
        ),
        invoice(
          id: 'settled',
          amountPesewas: 20000,
          amountPaidPesewas: 20000,
          dueDate: DateTime(2026, 2, 1),
          invoiceDate: DateTime(2026, 3, 18),
        ),
      ];

      final summary = summarise(
        invoices: invoices,
        payments: <Payment>[
          payment('p1', DateTime(2026, 3, 18), 15000, 'part'),
          payment('p2', DateTime(2026, 2, 20), 5000, 'settled'),
        ],
        supplierCount: 2,
        productCount: 5,
        now: now,
      );

      expect(summary.outstanding, 105000);
      expect(summary.overdue, 30000);
      expect(summary.overdueCount, 1);
      expect(summary.openCount, 3);
      expect(summary.settledCount, 1);
      expect(summary.invoiceCount, 4);
      expect(summary.paidThisMonth, 15000);
      // Bought this month: 50000 open + 40000 part-paid + 20000 already
      // settled in full. The February invoice does not count.
      expect(summary.invoicedThisMonth, 110000);
      expect(summary.invoicedTotal, 140000);
      expect(summary.paidTotal, 35000);
      expect(summary.supplierCount, 2);
      expect(summary.productCount, 5);
      expect(summary.outstandingShare, closeTo(105000 / 140000, 0.0001));
      expect(summary.isEmpty, isFalse);
    });

    test('an empty ledger summarises to zero rather than to a NaN share', () {
      final summary = summarise(
        invoices: const <SupplierInvoice>[],
        payments: const <Payment>[],
        supplierCount: 0,
        productCount: 0,
        now: now,
      );

      expect(summary.isEmpty, isTrue);
      expect(summary.outstandingShare, 0);
      expect(summary.outstanding, 0);
      expect(summary.overdueCount, 0);
    });
  });

  test('monthlyTrend returns one point per month, oldest first', () {
    final trend = monthlyTrend(
      invoices: <SupplierInvoice>[
        invoice(
          id: 'a',
          amountPesewas: 10000,
          invoiceDate: DateTime(2026, 3, 2),
        ),
        invoice(
          id: 'b',
          amountPesewas: 25000,
          invoiceDate: DateTime(2025, 11, 2),
        ),
        // Older than the window, so it must not appear anywhere.
        invoice(
          id: 'old',
          amountPesewas: 99000,
          invoiceDate: DateTime(2025, 1, 2),
        ),
      ],
      payments: <Payment>[
        payment('p1', DateTime(2026, 1, 9), 5000, 'a'),
      ],
      now: now,
    );

    expect(trend, hasLength(6));
    // Six months back from March 2026 is October 2025.
    expect(trend.first.month, DateTime(2025, 10));
    expect(trend.last.month, DateTime(2026, 3));
    expect(trend[1].month, DateTime(2025, 11));
    expect(trend.last.invoiced, 10000);
    expect(trend[1].invoiced, 25000);
    // The payment lands in January 2026, the fourth point of the window.
    expect(trend[3].paid, 5000);
    // A month with nothing in it still holds its place in the rhythm.
    expect(trend.first.invoiced, 0);
  });

  test('supplierShares orders by what is owed, settled ones last', () {
    final shares = supplierShares(
      invoices: <SupplierInvoice>[
        invoice(id: 'a', supplierId: 's1', amountPesewas: 10000),
        invoice(id: 'b', supplierId: 's2', amountPesewas: 90000),
        invoice(
          id: 'c',
          supplierId: 's3',
          amountPesewas: 70000,
          amountPaidPesewas: 70000,
        ),
      ],
      suppliers: <Supplier>[
        supplier('s1', 'Alpha'),
        supplier('s2', 'Bravo'),
        supplier('s3', 'Charlie'),
      ],
      now: now,
    );

    expect(
      shares.map((s) => s.supplier.name),
      <String>['Bravo', 'Alpha', 'Charlie'],
    );
    expect(shares.first.outstanding, 90000);
    expect(shares.first.invoiceCount, 1);
    expect(shares.last.outstanding, 0);
  });

  test('needsAttention lists only overdue invoices, biggest balance first', () {
    final late = needsAttention(
      invoices: <SupplierInvoice>[
        invoice(
          id: 'small',
          amountPesewas: 1000,
          dueDate: DateTime(2026, 3, 1),
        ),
        invoice(
          id: 'big',
          amountPesewas: 8000,
          dueDate: DateTime(2026, 3, 10),
        ),
        invoice(id: 'fine', amountPesewas: 5000, dueDate: DateTime(2026, 5, 1)),
      ],
      now: now,
    );

    expect(late.map((i) => i.id), <String>['big', 'small']);
    expect(daysLate(late.first, now), 10);
  });
}
