import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:pfa_pharmacy_invoice_tracker/data/app_database.dart';
import 'package:pfa_pharmacy_invoice_tracker/data/receipt_storage.dart';
import 'package:pfa_pharmacy_invoice_tracker/models/business_profile.dart';
import 'package:pfa_pharmacy_invoice_tracker/models/payment.dart';
import 'package:pfa_pharmacy_invoice_tracker/models/print_settings.dart';
import 'package:pfa_pharmacy_invoice_tracker/models/product.dart';
import 'package:pfa_pharmacy_invoice_tracker/models/supplier.dart';
import 'package:pfa_pharmacy_invoice_tracker/models/supplier_invoice.dart';

class InMemoryLocalStore implements LocalStore {
  InMemoryLocalStore({
    List<Supplier>? suppliers,
    List<SupplierInvoice>? invoices,
    List<Product>? products,
    List<Payment>? payments,
    BusinessProfile? profile,
    PrintSettings? printSettings,
  })  : suppliers = suppliers ?? [],
        invoices = invoices ?? [],
        products = products ?? [],
        payments = payments ?? [],
        profile = profile ?? BusinessProfile(),
        printSettings = printSettings ?? PrintSettings();

  List<Supplier> suppliers;
  List<SupplierInvoice> invoices;
  List<Product> products;
  List<Payment> payments;
  BusinessProfile profile;
  PrintSettings printSettings;

  @override
  String? get loadWarning => null;

  @override
  Future<List<Supplier>> loadSuppliers() async => List.of(suppliers);

  @override
  Future<List<SupplierInvoice>> loadInvoices() async => List.of(invoices);

  @override
  Future<List<Product>> loadProducts() async => List.of(products);

  @override
  Future<List<Payment>> loadPayments() async => List.of(payments);

  @override
  Future<void> saveSuppliers(List<Supplier> items) async {
    suppliers = List.of(items);
  }

  @override
  Future<void> saveInvoices(List<SupplierInvoice> items) async {
    invoices = List.of(items);
  }

  @override
  Future<void> saveProducts(List<Product> items) async {
    products = List.of(items);
  }

  @override
  Future<void> savePayments(List<Payment> items) async {
    payments = List.of(items);
  }

  @override
  Future<BusinessProfile> loadProfile() async => profile;

  @override
  Future<void> saveProfile(BusinessProfile value) async {
    profile = value;
  }

  @override
  Future<PrintSettings> loadPrintSettings() async => printSettings;

  @override
  Future<void> savePrintSettings(PrintSettings value) async {
    printSettings = value;
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
  Future<String> copyReceiptAs(String sourcePath, String storedName) async {
    await Directory(root).create(recursive: true);
    await File(sourcePath).copy(_path(storedName));
    return storedName;
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

  @override
  Future<List<String>> listReceipts() async {
    final d = Directory(root);
    if (!await d.exists()) return <String>[];
    return d
        .listSync()
        .whereType<File>()
        .map((f) => p.basename(f.path))
        .toList();
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
  String notes = '',
  List<String> receipts = const [],
  List<InvoiceLine> lines = const [],
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
    notes: notes,
    receipts: receipts,
    lines: lines,
  );
}