import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_database.dart';
import '../../models/supplier_invoice.dart';

class InvoicesController extends StateNotifier<List<SupplierInvoice>> {
  InvoicesController(this._store) : super(const []) {
    _load();
  }

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
}

final invoicesProvider =
    StateNotifierProvider<InvoicesController, List<SupplierInvoice>>((ref) {
  return InvoicesController(ref.watch(localStoreProvider));
});