import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_database.dart';
import '../../models/supplier.dart';

class SuppliersController extends StateNotifier<List<Supplier>> {
  SuppliersController(this._store) : super(const []) {
    _load();
  }

  final LocalStore _store;

  Future<void> _load() async {
    state = await _store.loadSuppliers();
  }

  Future<void> refresh() => _load();

  Future<void> add(Supplier supplier) async {
    state = [supplier, ...state];
    await _store.saveSuppliers(state);
  }

  /// Adds a batch in one write, used when an Excel import names suppliers that
  /// are not in the app yet.
  Future<void> addMany(List<Supplier> suppliers) async {
    if (suppliers.isEmpty) return;
    final known = state.map((s) => s.name.trim().toLowerCase()).toSet();
    final fresh = [
      for (final s in suppliers)
        if (!known.contains(s.name.trim().toLowerCase())) s,
    ];
    if (fresh.isEmpty) return;
    state = [...fresh, ...state];
    await _store.saveSuppliers(state);
  }

  Future<void> update(Supplier supplier) async {
    state = [
      for (final s in state) s.id == supplier.id ? supplier : s,
    ];
    await _store.saveSuppliers(state);
  }

  Future<void> remove(String id) async {
    state = state.where((s) => s.id != id).toList();
    await _store.saveSuppliers(state);
  }
}

final suppliersProvider =
    StateNotifierProvider<SuppliersController, List<Supplier>>((ref) {
  return SuppliersController(ref.watch(localStoreProvider));
});