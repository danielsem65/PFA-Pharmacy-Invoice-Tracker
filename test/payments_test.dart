import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pfa_pharmacy_invoice_tracker/data/app_database.dart';
import 'package:pfa_pharmacy_invoice_tracker/features/invoices/invoices_controller.dart';
import 'package:pfa_pharmacy_invoice_tracker/features/payments/payments_controller.dart';
import 'package:pfa_pharmacy_invoice_tracker/models/payment.dart';
import 'package:pfa_pharmacy_invoice_tracker/models/supplier_invoice.dart';

import 'helpers.dart';

ProviderContainer containerFor(InMemoryLocalStore store) {
  final container = ProviderContainer(
    overrides: <Override>[localStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('payment records', () {
    test('a payment keeps its total and survives a save and load', () async {
      final store = InMemoryLocalStore();
      final payment = Payment(
        date: DateTime(2026, 3, 4),
        method: 'Bank Pay',
        reference: 'TELLER-77',
        allocations: const <PaymentAllocation>[
          PaymentAllocation(invoiceId: 'i1', amountPesewas: 4000),
          PaymentAllocation(invoiceId: 'i2', amountPesewas: 1500),
        ],
      );

      await store.savePayments(<Payment>[payment]);

      final loaded = await store.loadPayments();
      expect(loaded, hasLength(1));
      expect(loaded.single.amountPesewas, 5500);
      expect(loaded.single.method, 'Bank Pay');
      expect(loaded.single.reference, 'TELLER-77');
      expect(loaded.single.date, DateTime(2026, 3, 4));
      expect(loaded.single.invoiceIds, <String>{'i1', 'i2'});
    });

    test('recording one payment settles two invoices at once', () async {
      final container = containerFor(
        InMemoryLocalStore(
          invoices: <SupplierInvoice>[
            invoice(id: 'i1', amountPesewas: 10000),
            invoice(id: 'i2', amountPesewas: 20000),
          ],
        ),
      );

      await container.read(paymentsProvider.notifier).ready;
      await container.read(paymentsProvider.notifier).add(
            Payment(
              date: DateTime(2026, 4, 1),
              allocations: const <PaymentAllocation>[
                PaymentAllocation(invoiceId: 'i1', amountPesewas: 10000),
                PaymentAllocation(invoiceId: 'i2', amountPesewas: 5000),
              ],
            ),
          );

      final invoices = container.read(invoicesProvider);
      final first = invoices.firstWhere((i) => i.id == 'i1');
      final second = invoices.firstWhere((i) => i.id == 'i2');
      expect(first.amountPaidPesewas, 10000);
      expect(first.balancePesewas, 0);
      expect(second.amountPaidPesewas, 5000);
      expect(second.balancePesewas, 15000);
      expect(container.read(paymentsProvider), hasLength(1));
    });

    test('a partly paid invoice shows as partial, not paid', () async {
      final container = containerFor(
        InMemoryLocalStore(
          invoices: <SupplierInvoice>[
            invoice(
              id: 'i1',
              amountPesewas: 10000,
              dueDate: DateTime(2030, 1, 31),
            ),
          ],
        ),
      );

      await container.read(paymentsProvider.notifier).ready;
      await container.read(paymentsProvider.notifier).add(
            Payment(
              date: DateTime(2026, 4, 1),
              allocations: const <PaymentAllocation>[
                PaymentAllocation(invoiceId: 'i1', amountPesewas: 2500),
              ],
            ),
          );

      final inv = container.read(invoicesProvider).single;
      expect(inv.amountPaidPesewas, 2500);
      expect(inv.owesMoney, isTrue);
      expect(
        inv.statusAt(DateTime(2026, 4, 2)),
        InvoiceStatus.partiallyPaid,
      );
    });

    test('a settled invoice is stamped with the day it was paid', () async {
      final container = containerFor(
        InMemoryLocalStore(
          invoices: <SupplierInvoice>[
            invoice(id: 'i1', amountPesewas: 10000),
          ],
        ),
      );

      await container.read(paymentsProvider.notifier).ready;
      await container.read(paymentsProvider.notifier).add(
            Payment(
              date: DateTime(2026, 4, 1),
              allocations: const <PaymentAllocation>[
                PaymentAllocation(invoiceId: 'i1', amountPesewas: 10000),
              ],
            ),
          );

      final inv = container.read(invoicesProvider).single;
      expect(inv.paidDate, isNotNull);
      expect(inv.statusAt(DateTime(2026, 4, 2)), InvoiceStatus.paid);
    });

    test('deleting a payment gives the money back to the invoice', () async {
      final container = containerFor(
        InMemoryLocalStore(
          invoices: <SupplierInvoice>[
            invoice(id: 'i1', amountPesewas: 10000),
          ],
        ),
      );

      await container.read(paymentsProvider.notifier).ready;
      final notifier = container.read(paymentsProvider.notifier);
      await notifier.add(
        Payment(
          date: DateTime(2026, 4, 1),
          allocations: const <PaymentAllocation>[
            PaymentAllocation(invoiceId: 'i1', amountPesewas: 6000),
          ],
        ),
      );
      expect(container.read(invoicesProvider).single.amountPaidPesewas, 6000);

      await notifier.remove(container.read(paymentsProvider).single.id);

      expect(container.read(paymentsProvider), isEmpty);
      expect(container.read(invoicesProvider).single.amountPaidPesewas, 0);
      expect(container.read(invoicesProvider).single.balancePesewas, 10000);
    });

    test('an overpayment can never push an invoice past its total', () async {
      final container = containerFor(
        InMemoryLocalStore(
          invoices: <SupplierInvoice>[
            invoice(id: 'i1', amountPesewas: 10000),
          ],
        ),
      );

      await container.read(paymentsProvider.notifier).ready;
      await container.read(paymentsProvider.notifier).add(
            Payment(
              date: DateTime(2026, 4, 1),
              allocations: const <PaymentAllocation>[
                PaymentAllocation(invoiceId: 'i1', amountPesewas: 99999),
              ],
            ),
          );

      final inv = container.read(invoicesProvider).single;
      expect(inv.amountPaidPesewas, 10000);
      expect(inv.balancePesewas, 0);
    });

    test('a supplier total adds up what they were paid and what is left',
        () async {
      final container = containerFor(
        InMemoryLocalStore(
          invoices: <SupplierInvoice>[
            invoice(id: 'i1', supplierId: 's1', amountPesewas: 10000),
            invoice(id: 'i2', supplierId: 's1', amountPesewas: 20000),
            invoice(id: 'i3', supplierId: 's2', amountPesewas: 5000),
          ],
        ),
      );

      await container.read(paymentsProvider.notifier).ready;
      await container.read(paymentsProvider.notifier).add(
            Payment(
              date: DateTime(2026, 4, 1),
              allocations: const <PaymentAllocation>[
                PaymentAllocation(invoiceId: 'i1', amountPesewas: 10000),
                PaymentAllocation(invoiceId: 'i2', amountPesewas: 5000),
              ],
            ),
          );

      final one = container.read(supplierPaymentTotalsProvider('s1'));
      expect(one.paidPesewas, 15000);
      expect(one.outstandingPesewas, 15000);

      final two = container.read(supplierPaymentTotalsProvider('s2'));
      expect(two.paidPesewas, 0);
      expect(two.outstandingPesewas, 5000);
    });
  });

  group('paid amounts typed straight onto an invoice', () {
    test('become payment records dated to the day it was settled', () {
      final seeded = legacyPaymentsFor(
        <SupplierInvoice>[
          invoice(
            id: 'i1',
            amountPesewas: 10000,
            amountPaidPesewas: 10000,
            paidDate: DateTime(2026, 1, 20),
            paymentMethod: 'Cheque',
          ),
          invoice(id: 'i2', amountPesewas: 5000),
        ],
        const <Payment>[],
      );

      expect(seeded, hasLength(1));
      expect(seeded.single.date, DateTime(2026, 1, 20));
      expect(seeded.single.method, 'Cheque');
      expect(seeded.single.isLegacy, isTrue);
      expect(seeded.single.amountPesewas, 10000);
      expect(seeded.single.invoiceIds, <String>{'i1'});
    });

    test('are only seeded once, never doubled on a second load', () {
      final invoices = <SupplierInvoice>[
        invoice(id: 'i1', amountPesewas: 10000, amountPaidPesewas: 4000),
      ];
      final first = legacyPaymentsFor(invoices, const <Payment>[]);
      final second = legacyPaymentsFor(invoices, first);
      expect(second, isEmpty);
    });

    test('top up only the part a later payment did not cover', () {
      final invoices = <SupplierInvoice>[
        invoice(id: 'i1', amountPesewas: 10000, amountPaidPesewas: 9000),
      ];
      final existing = <Payment>[
        Payment(
          date: DateTime(2026, 2, 2),
          allocations: const <PaymentAllocation>[
            PaymentAllocation(invoiceId: 'i1', amountPesewas: 4000),
          ],
        ),
      ];

      final topped = legacyPaymentsFor(invoices, existing);
      expect(topped, hasLength(1));
      expect(topped.single.amountPesewas, 5000);
    });

    test('an invoice nobody paid for gains nothing', () {
      expect(
        legacyPaymentsFor(<SupplierInvoice>[invoice()], const <Payment>[]),
        isEmpty,
      );
    });

    test('start-up seeding leaves the invoice totals exactly as they were',
        () async {
      final store = InMemoryLocalStore(
        invoices: <SupplierInvoice>[
          invoice(
            id: 'i1',
            amountPesewas: 10000,
            amountPaidPesewas: 10000,
            paidDate: DateTime(2026, 1, 20),
          ),
          invoice(id: 'i2', amountPesewas: 5000),
        ],
      );
      final container = containerFor(store);

      // Reading the ledger is what seeds the records for invoices that were
      // marked paid before the ledger existed.
      await container.read(paymentsProvider.notifier).ready;

      final invoices = container.read(invoicesProvider);
      expect(invoices.firstWhere((i) => i.id == 'i1').amountPaidPesewas, 10000);
      expect(invoices.firstWhere((i) => i.id == 'i2').amountPaidPesewas, 0);
      expect(container.read(paymentsProvider), hasLength(1));
      expect(store.payments, hasLength(1));
    });
  });
}
