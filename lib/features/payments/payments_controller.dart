import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_database.dart';
import '../../models/payment.dart';
import '../../models/supplier_invoice.dart';
import '../invoices/invoices_controller.dart';

class PaymentsController extends StateNotifier<List<Payment>> {
  PaymentsController(this._store, this._ref) : super(const []) {
    _load();
  }

  final LocalStore _store;
  final Ref _ref;

  Future<void> _load() async {
    state = await _store.loadPayments();
  }

  Future<void> refresh() => _load();

  /// Records a payment and moves every invoice it covers toward settled. The
  /// invoice's paid amount is the running total of the records that touch it,
  /// so the balance on the invoice page can never drift from the ledger.
  Future<void> add(Payment payment) async {
    if (payment.isEmpty) return;
    state = [payment, ...state];
    await _store.savePayments(state);
    await _applyToInvoices(
      allocationsByInvoice: {
        for (final a in payment.allocations) a.invoiceId: a.amountPesewas,
      },
      sign: 1,
    );
  }

  /// Adds records that only record something already true, so the invoice
  /// totals are left alone.
  Future<void> addMany(List<Payment> payments) async {
    if (payments.isEmpty) return;
    state = [...payments, ...state];
    await _store.savePayments(state);
  }

  /// Deletes a record and gives the money back to the invoices it covered, so
  /// a payment removed by mistake leaves no phantom credit behind.
  Future<void> remove(String id) async {
    Payment? found;
    for (final p in state) {
      if (p.id == id) {
        found = p;
        break;
      }
    }
    if (found == null) return;
    state = state.where((p) => p.id != id).toList();
    await _store.savePayments(state);
    await _applyToInvoices(
      allocationsByInvoice: {
        for (final a in found.allocations) a.invoiceId: a.amountPesewas,
      },
      sign: -1,
    );
  }

  Future<void> _applyToInvoices({
    required Map<String, int> allocationsByInvoice,
    required int sign,
  }) async {
    if (allocationsByInvoice.isEmpty) return;
    final invoices = await _ref.read(invoicesProvider.future);
    if (invoices.isEmpty) return;
    final now = DateTime.now();
    final updated = [
      for (final inv in invoices)
        if (allocationsByInvoice.containsKey(inv.id))
          _withPayment(inv, sign * (allocationsByInvoice[inv.id] ?? 0), now)
        else
          inv,
    ];
    await _ref.read(invoicesProvider.notifier).replaceAll(updated);
  }

  SupplierInvoice _withPayment(SupplierInvoice inv, int delta, DateTime now) {
    final paid =
        (inv.amountPaidPesewas + delta).clamp(0, inv.totalPesewas).toInt();
    final settled = paid >= inv.totalPesewas;
    return inv.copyWith(
      amountPaidPesewas: paid,
      // A fully settled invoice keeps the day it was paid, so a partly paid
      // invoice never carries a stale date.
      paidDate: settled ? now : null,
      clearPaidDate: !settled,
    );
  }
}

final paymentsProvider =
    StateNotifierProvider<PaymentsController, List<Payment>>((ref) {
  return PaymentsController(ref.watch(localStoreProvider), ref);
});

/// Turns any hand-typed paid amount that has no payment record into one, and
/// keeps doing so on every load so nothing is ever left unexplained. Runs at
/// start-up, before the payments page is opened.
final paymentSyncProvider = FutureProvider<void>((ref) async {
  final invoices = await ref.watch(invoicesProvider.future);
  final existing = ref.watch(paymentsProvider);
  final missing = legacyPaymentsFor(invoices, existing);
  if (missing.isEmpty) return;
  await ref.read(paymentsProvider.notifier).addMany(missing);
});

/// What the payments page shows per supplier: how much has been paid, and how
/// much is still owed once every record has been taken into account.
class SupplierPaymentTotals {
  const SupplierPaymentTotals({
    required this.paidPesewas,
    required this.outstandingPesewas,
  });

  final int paidPesewas;
  final int outstandingPesewas;
}

final supplierPaymentTotalsProvider =
    Provider.family<SupplierPaymentTotals, String>((ref, supplierId) {
  final invoices = ref
      .watch(invoicesProvider)
      .where((i) => i.supplierId == supplierId)
      .toList();
  final paid = invoices.fold(0, (sum, i) => sum + i.amountPaidPesewas);
  final outstanding = invoices.fold(0, (sum, i) => sum + i.balancePesewas);
  return SupplierPaymentTotals(
    paidPesewas: paid,
    outstandingPesewas: outstanding < 0 ? 0 : outstanding,
  );
});
