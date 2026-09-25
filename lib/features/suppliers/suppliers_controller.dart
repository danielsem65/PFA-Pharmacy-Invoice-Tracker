import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/app_database.dart';
import '../../models/supplier.dart';

final localStoreProvider = Provider<LocalStore>((ref) {
  return SharedPrefsLocalStore(SharedPreferencesAsync());
});

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