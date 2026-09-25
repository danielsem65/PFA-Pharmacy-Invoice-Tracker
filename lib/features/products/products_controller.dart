import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_database.dart';
import '../../models/product.dart';

class ProductsController extends StateNotifier<List<Product>> {
  ProductsController(this._store, this._ref) : super(const []) {
    _load();
  }

  final LocalStore _store;
  final Ref _ref;

  Future<void> _load() async {
    state = await _store.loadProducts();
    _publishWarning();
  }

  Future<void> refresh() => _load();

  Future<void> add(Product product) async {
    state = [product, ...state];
    await _store.saveProducts(state);
  }

  Future<void> update(Product product) async {
    state = [
      for (final p in state) p.id == product.id ? product : p,
    ];
    await _store.saveProducts(state);
  }

  Future<void> remove(String id) async {
    state = state.where((p) => p.id != id).toList();
    await _store.saveProducts(state);
  }

  void _publishWarning() {
    final warning = _store.loadWarning;
    if (warning == null || warning.isEmpty) return;
    if (_ref.read(dataWarningProvider) == warning) return;
    _ref.read(dataWarningProvider.notifier).state = warning;
  }
}

final productsProvider =
    StateNotifierProvider<ProductsController, List<Product>>((ref) {
  return ProductsController(ref.watch(localStoreProvider), ref);
});
