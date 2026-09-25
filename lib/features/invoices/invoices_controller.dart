import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_database.dart';
import '../../models/supplier_invoice.dart';

class InvoicesController extends StateNotifier<List<SupplierInvoice>> {
  InvoicesController(this._store) : super(const []) {
    ready = _load();
  }

  /// Completes once the saved invoices are in memory, so anything that has to
  /// reason about them can wait for them instead of guessing.
  late final Future<void> ready;

  final LocalStore _store;

  Future<void> _load() async {
    state = await _store.loadInvoices();
  }

  Future<void> refresh() => _load();

  Future<void> upsert(SupplierInvoice invoice) async {
    final index = state.indexWhere((i) => i.id == invoice.id);
    if (index == -1) {
      state = [invoice, ...state];
    } else {
      state = [
        for (final i in state) i.id == invoice.id ? invoice : i,
      ];
    }
    await _store.saveInvoices(state);
  }

  Future<void> remove(String id) async {
    state = state.where((i) => i.id != id).toList();
    await _store.saveInvoices(state);
  }

  Future<void> removeMany(Set<String> ids) async {
    state = state.where((i) => !ids.contains(i.id)).toList();
    await _store.saveInvoices(state);
  }

  /// Replaces the whole list in one write, used when a payment moves the paid
  /// amount on several invoices at once.
  Future<void> replaceAll(List<SupplierInvoice> invoices) async {
    state = invoices;
    await _store.saveInvoices(state);
  }

  /// Adds a batch in one write, used by the Excel import so a large sheet is
  /// saved once instead of once per invoice.
  Future<void> addMany(List<SupplierInvoice> invoices) async {
    if (invoices.isEmpty) return;
    final known = state.map((i) => i.id).toSet();
    final fresh = invoices.where((i) => !known.contains(i.id)).toList();
    if (fresh.isEmpty) return;
    state = [...fresh, ...state];
    await _store.saveInvoices(state);
  }
}

final invoicesProvider =
    StateNotifierProvider<InvoicesController, List<SupplierInvoice>>((ref) {
  return InvoicesController(ref.watch(localStoreProvider));
});