import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_database.dart';
import '../../models/payment.dart';
import '../../models/supplier_invoice.dart';
import '../invoices/invoices_controller.dart';

class PaymentsController extends StateNotifier<List<Payment>> {
  PaymentsController(this._store, this._ref) : super(const []) {
    ready = _load();
  }

  /// Completes once the saved payment records are in memory, including the
  /// ones seeded for paid amounts that predate the ledger.
  late final Future<void> ready;

  final LocalStore _store;
  final Ref _ref;

  Future<void> _load() async {
    final stored = await _store.loadPayments();
    // Turn any paid amount that was typed straight onto an invoice into a
    // record, so the ledger explains every peso from the first day. Running it
    // on every load is what makes it safe: an invoice that is already covered
    // gains nothing.
    await _ref.read(invoicesProvider.notifier).ready;
    final seeded = legacyPaymentsFor(_ref.read(invoicesProvider), stored);
    state = [...seeded, ...stored];
    if (seeded.isNotEmpty) await _store.savePayments(state);
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
    await _ref.read(invoicesProvider.notifier).ready;
    final invoices = _ref.read(invoicesProvider);
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
  var paid = 0;
  var outstanding = 0;
  for (final inv in ref.watch(invoicesProvider)) {
    if (inv.supplierId != supplierId) continue;
    paid += inv.amountPaidPesewas;
    outstanding += inv.balancePesewas;
  }
  return SupplierPaymentTotals(
    paidPesewas: paid,
    outstandingPesewas: outstanding < 0 ? 0 : outstanding,
  );
});
