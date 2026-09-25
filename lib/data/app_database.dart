import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/payment.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../models/supplier_invoice.dart';

/// Holds a warning produced while reading data (e.g. a damaged file that was
/// recovered from the safety copy) so the UI can tell the user.
final dataWarningProvider = StateProvider<String?>((ref) => null);

final localStoreProvider = Provider<LocalStore>((ref) {
  return SharedPrefsLocalStore(SharedPrefsKeyValueStore(SharedPreferencesAsync()));
});

/// Minimal key/value contract so the store can be unit tested without the
/// shared_preferences platform channel.
abstract class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SharedPrefsKeyValueStore implements KeyValueStore {
  SharedPrefsKeyValueStore(this._prefs);

  final SharedPreferencesAsync _prefs;

  @override
  Future<String?> read(String key) => _prefs.getString(key);

  @override
  Future<void> write(String key, String value) =>
      _prefs.setString(key, value);
}

abstract class LocalStore {
  Future<List<Supplier>> loadSuppliers();
  Future<List<SupplierInvoice>> loadInvoices();
  Future<List<Product>> loadProducts();
  Future<List<Payment>> loadPayments();
  Future<void> saveSuppliers(List<Supplier> suppliers);
  Future<void> saveInvoices(List<SupplierInvoice> invoices);
  Future<void> saveProducts(List<Product> products);
  Future<void> savePayments(List<Payment> payments);

  /// Non-null when the last load hit damaged data. The list is only
  /// non-empty once per app run, so the UI can warn exactly once.
  String? get loadWarning;
}

class SharedPrefsLocalStore implements LocalStore {
  SharedPrefsLocalStore(this._prefs);

  static const _suppliersKey = 'pfa.suppliers.v1';
  static const _invoicesKey = 'pfa.invoices.v1';
  static const _productsKey = 'pfa.products.v1';
  static const _paymentsKey = 'pfa.payments.v1';
  static const _backupSuffix = '.bak';

  final KeyValueStore _prefs;
  final List<String> _warnings = [];

  @override
  String? get loadWarning => _warnings.isEmpty ? null : _warnings.join('\n\n');

  @override
  Future<List<Supplier>> loadSuppliers() =>
      _loadList(_suppliersKey, Supplier.fromJson, 'suppliers');

  @override
  Future<List<SupplierInvoice>> loadInvoices() =>
      _loadList(_invoicesKey, SupplierInvoice.fromJson, 'invoices');

  @override
  Future<List<Product>> loadProducts() =>
      _loadList(_productsKey, Product.fromJson, 'products');

  @override
  Future<List<Payment>> loadPayments() =>
      _loadList(_paymentsKey, Payment.fromJson, 'payments');

  @override
  Future<void> saveSuppliers(List<Supplier> suppliers) => _saveList(
        _suppliersKey,
        suppliers.map((e) => e.toJson()).toList(),
      );

  @override
  Future<void> saveInvoices(List<SupplierInvoice> invoices) => _saveList(
        _invoicesKey,
        invoices.map((e) => e.toJson()).toList(),
      );

  @override
  Future<void> saveProducts(List<Product> products) => _saveList(
        _productsKey,
        products.map((e) => e.toJson()).toList(),
      );

  @override
  Future<void> savePayments(List<Payment> payments) => _saveList(
        _paymentsKey,
        payments.map((e) => e.toJson()).toList(),
      );

  Future<List<T>> _loadList<T>(
    String key,
    T Function(Map<String, dynamic>) decode,
    String label,
  ) async {
    final raw = await _prefs.read(key);
    if (raw == null || raw.isEmpty) return <T>[];
    try {
      return _decodeList<T>(raw, decode);
    } catch (_) {
      // The live file is damaged. Fall back to the last known-good copy so a
      // single bad write can never look like "all my data disappeared".
      final backup = await _prefs.read('$key$_backupSuffix');
      if (backup != null && backup.isNotEmpty) {
        try {
          final recovered = _decodeList<T>(backup, decode);
          _warn(
            'Your $label file was damaged, so the last good copy was loaded '
            'instead. Use ⋮ → Export backup (ZIP) now, then Restore backup… '
            'on any invoices you are missing.',
          );
          return recovered;
        } catch (_) {
          // Fall through to the hard failure below.
        }
      }
      _warn(
        'Your $label file could not be read and no safety copy exists. '
        'Do not delete or overwrite records — restore a backup from '
        '⋮ → Restore backup… first.',
      );
      return <T>[];
    }
  }

  List<T> _decodeList<T>(
    String raw,
    T Function(Map<String, dynamic>) decode,
  ) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => decode(e as Map<String, dynamic>)).toList();
  }

  Future<void> _saveList(
    String key,
    List<Map<String, dynamic>> items,
  ) async {
    final raw = jsonEncode(items);
    final current = await _prefs.read(key);
    if (current != null && current.isNotEmpty && current != raw) {
      await _prefs.write('$key$_backupSuffix', current);
    }
    await _prefs.write(key, raw);
  }

  void _warn(String message) {
    if (!_warnings.contains(message)) _warnings.add(message);
  }
}
