import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:pfa_pharmacy_invoice_tracker/data/app_database.dart';
import 'package:pfa_pharmacy_invoice_tracker/data/receipt_storage.dart';
import 'package:pfa_pharmacy_invoice_tracker/models/supplier.dart';
import 'package:pfa_pharmacy_invoice_tracker/models/supplier_invoice.dart';

class InMemoryLocalStore implements LocalStore {
  InMemoryLocalStore({
    List<Supplier>? suppliers,
    List<SupplierInvoice>? invoices,
  })  : suppliers = suppliers ?? [],
        invoices = invoices ?? [];

  List<Supplier> suppliers;
  List<SupplierInvoice> invoices;

  @override
  Future<List<Supplier>> loadSuppliers() async => List.of(suppliers);

  @override
  Future<List<SupplierInvoice>> loadInvoices() async => List.of(invoices);

  @override
  Future<void> saveSuppliers(List<Supplier> items) async {
    suppliers = List.of(items);
  }

  @override
  Future<void> saveInvoices(List<SupplierInvoice> items) async {
    invoices = List.of(items);
  }
}

class TestReceiptStorage extends ReceiptStorage {
  TestReceiptStorage(this.root);

  final String root;

  String _path(String name) => p.join(root, name);

  @override
  Future<String> receiptPath(String storedName) async => _path(storedName);

  @override
  Future<String> saveReceiptFile(String sourcePath) async {
    final name = sanitizeName(sourcePath);
    await Directory(root).create(recursive: true);
    await File(sourcePath).copy(_path(name));
    return name;
  }

  @override
  Future<List<int>> readReceipt(String storedName) async {
    return File(_path(storedName)).readAsBytes();
  }

  @override
  Future<void> writeReceipt(String storedName, List<int> bytes) async {
    await Directory(root).create(recursive: true);
    await File(_path(storedName)).writeAsBytes(bytes);
  }

  @override
  Future<void> deleteReceiptFile(String storedName) async {
    final f = File(_path(storedName));
    if (await f.exists()) await f.delete();
  }

  @override
  Future<void> deleteAll() async {
    final d = Directory(root);
    if (await d.exists()) await d.delete(recursive: true);
  }
}

Supplier supplier(String id, String name) =>
    Supplier(id: id, name: name, phone: '555', location: 'Accra');

SupplierInvoice invoice({
  String id = 'i1',
  String supplierId = 's1',
  String invoiceNumber = 'INV-1',
  DateTime? invoiceDate,
  DateTime? receivedDate,
  DateTime? dueDate,
  int amountPesewas = 10000,
  double taxRatePercent = 0,
  int amountPaidPesewas = 0,
  DateTime? paidDate,
  String? reference,
  String? description,
  String paymentMethod = 'Cash',
  List<String> receipts = const [],
}) {
  return SupplierInvoice(
    id: id,
    supplierId: supplierId,
    invoiceNumber: invoiceNumber,
    invoiceDate: invoiceDate ?? DateTime(2000, 1, 1),
    receivedDate: receivedDate ?? DateTime(2000, 1, 1),
    dueDate: dueDate ?? DateTime(2000, 1, 31),
    amountPesewas: amountPesewas,
    taxRatePercent: taxRatePercent,
    amountPaidPesewas: amountPaidPesewas,
    paidDate: paidDate,
    reference: reference ?? '',
    description: description ?? '',
    paymentMethod: paymentMethod,
    receipts: receipts,
  );
}