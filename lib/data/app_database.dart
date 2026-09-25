import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/supplier.dart';
import '../models/supplier_invoice.dart';

abstract class LocalStore {
  Future<List<Supplier>> loadSuppliers();
  Future<List<SupplierInvoice>> loadInvoices();
  Future<void> saveSuppliers(List<Supplier> suppliers);
  Future<void> saveInvoices(List<SupplierInvoice> invoices);
}

class SharedPrefsLocalStore implements LocalStore {
  SharedPrefsLocalStore(this._prefs);

  static const _suppliersKey = 'pfa.suppliers.v1';
  static const _invoicesKey = 'pfa.invoices.v1';

  final SharedPreferencesAsync _prefs;

  @override
  Future<List<Supplier>> loadSuppliers() async {
    final raw = await _prefs.getString(_suppliersKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Supplier.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<SupplierInvoice>> loadInvoices() async {
    final raw = await _prefs.getString(_invoicesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => SupplierInvoice.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveSuppliers(List<Supplier> suppliers) async {
    final raw = jsonEncode(suppliers.map((e) => e.toJson()).toList());
    await _prefs.setString(_suppliersKey, raw);
  }

  @override
  Future<void> saveInvoices(List<SupplierInvoice> invoices) async {
    final raw = jsonEncode(invoices.map((e) => e.toJson()).toList());
    await _prefs.setString(_invoicesKey, raw);
  }
}