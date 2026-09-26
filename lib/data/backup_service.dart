import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../models/payment.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../models/supplier_invoice.dart';
import 'app_database.dart';
import 'receipt_storage.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    store: ref.watch(localStoreProvider),
    receipts: ref.watch(receiptStorageProvider),
  );
});

class BackupContent {
  BackupContent({
    required this.suppliers,
    required this.invoices,
    required this.products,
    required this.receipts,
    this.payments,
  });

  final List<Supplier> suppliers;
  final List<SupplierInvoice> invoices;
  final List<Product> products;
  final Map<String, List<int>> receipts;

  /// Null when the backup was taken before payments existed. That is not the
  /// same as an empty ledger: restoring must leave the records she has now
  /// alone rather than quietly replacing them with nothing.
  final List<Payment>? payments;
}

class BackupService {
  BackupService({required this.store, required this.receipts});

  final LocalStore store;
  final ReceiptStorage receipts;

  static const _manifestName = 'manifest.json';

  Future<void> exportZip(String targetPath, {Set<String>? invoiceIds}) async {
    final allSuppliers = await store.loadSuppliers();
    final allInvoices = await store.loadInvoices();
    final allProducts = await store.loadProducts();
    final allPayments = await store.loadPayments();

    final withoutIds = invoiceIds == null;
    final invoices = invoiceIds == null
        ? allInvoices
        : allInvoices.where((i) => invoiceIds.contains(i.id)).toList();
    final usedSupplierIds = invoices.map((i) => i.supplierId).toSet();
    final suppliers = withoutIds
        ? allSuppliers
        : allSuppliers.where((s) => usedSupplierIds.contains(s.id)).toList();

    // A partial export only needs the products its invoices actually reference,
    // so the slice still restores on its own.
    final usedProductNames =
        invoices.expand((i) => i.lines).map((l) => l.name.trim().toLowerCase());
    final products = withoutIds
        ? allProducts
        : allProducts
            .where((p) => usedProductNames.contains(p.normalizedName))
            .toList();

    // A payment belongs to the invoices it settles, so a partial export keeps
    // only the records that touch the invoices it carries. The slice of those
    // records goes too, so the amounts in the backup still add up.
    final exportedIds = invoices.map((i) => i.id).toSet();
    final payments = [
      for (final pay in allPayments)
        if (pay.allocations.any((a) => exportedIds.contains(a.invoiceId)))
          pay.copyWith(
            allocations: [
              for (final a in pay.allocations)
                if (exportedIds.contains(a.invoiceId)) a,
            ],
          ),
    ];

    final archive = Archive();
    archive.addFile(ArchiveFile.string(
      'suppliers.json',
      jsonEncode(suppliers.map((e) => e.toJson()).toList()),
    ));
    archive.addFile(ArchiveFile.string(
      'invoices.json',
      jsonEncode(invoices.map((e) => e.toJson()).toList()),
    ));
    archive.addFile(ArchiveFile.string(
      'products.json',
      jsonEncode(products.map((e) => e.toJson()).toList()),
    ));
    archive.addFile(ArchiveFile.string(
      'payments.json',
      jsonEncode(payments.map((e) => e.toJson()).toList()),
    ));
    archive.addFile(ArchiveFile.string(
      _manifestName,
      jsonEncode({
        'app': 'pfa_pharmacy_invoice_tracker',
        'format': 3,
        'exportedAt': DateTime.now().toIso8601String(),
        'suppliers': suppliers.length,
        'invoices': invoices.length,
        'products': products.length,
        'payments': payments.length,
      }),
    ));

    final receiptNames = <String>{};
    for (final invoice in invoices) {
      receiptNames.addAll(invoice.receipts);
    }
    for (final name in receiptNames) {
      try {
        final bytes = await receipts.readReceipt(name);
        archive.addFile(ArchiveFile('receipts/$name', bytes.length, bytes));
      } catch (_) {
        // Skip missing receipt files.
      }
    }

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw const FileSystemException('Could not encode backup archive');
    }
    await File(targetPath).writeAsBytes(encoded);
  }

  Future<BackupContent> readZip(String sourcePath) async {
    final bytes = await File(sourcePath).readAsBytes();
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } catch (e) {
      throw FormatException('This file is not a valid backup archive.');
    }

    String? readString(String name) {
      final f = archive.findFile(name);
      if (f == null) return null;
      return utf8.decode(f.content as List<int>);
    }

    final suppliersRaw = readString('suppliers.json');
    final invoicesRaw = readString('invoices.json');
    if (suppliersRaw == null || invoicesRaw == null) {
      throw const FormatException(
        'This file is not a PFA Invoice Tracker backup.',
      );
    }

    final List<Supplier> suppliers;
    final List<SupplierInvoice> invoices;
    try {
      suppliers = (jsonDecode(suppliersRaw) as List<dynamic>)
          .map((e) => Supplier.fromJson(e as Map<String, dynamic>))
          .toList();
      invoices = (jsonDecode(invoicesRaw) as List<dynamic>)
          .map((e) => SupplierInvoice.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw const FormatException(
        'Backup data is corrupted and could not be read.',
      );
    }

    // Backups taken before the products feature have no products.json.
    final productsRaw = readString('products.json');
    var products = const <Product>[];
    if (productsRaw != null) {
      try {
        products = (jsonDecode(productsRaw) as List<dynamic>)
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        products = const <Product>[];
      }
    }

    // Likewise for payments: no payments.json means the backup predates the
    // ledger, which is not the same as saying the ledger was empty.
    final paymentsRaw = readString('payments.json');
    List<Payment>? payments;
    if (paymentsRaw != null) {
      try {
        payments = (jsonDecode(paymentsRaw) as List<dynamic>)
            .map((e) => Payment.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        payments = null;
      }
    }

    final receiptsMap = <String, List<int>>{};
    for (final f in archive.files) {
      if (!f.isFile || !f.name.startsWith('receipts/')) continue;
      final name = p.basename(f.name);
      if (name.isEmpty || name == '.' || name == '..') continue;
      if (receiptsMap.containsKey(name)) continue;
      receiptsMap[name] = f.content as List<int>;
    }

    return BackupContent(
      suppliers: suppliers,
      invoices: invoices,
      products: products,
      receipts: receiptsMap,
      payments: payments,
    );
  }

  Future<void> importZip(String sourcePath) async {
    final content = await readZip(sourcePath);
    await store.saveSuppliers(content.suppliers);
    await store.saveInvoices(content.invoices);
    await store.saveProducts(content.products);
    // Only a backup that carries records replaces the ledger. An older one
    // leaves the records already here untouched, and the paid amounts on the
    // restored invoices are re-read into records on the next load.
    if (content.payments != null) {
      await store.savePayments(content.payments!);
    }

    // Restore is a replace, not a merge: drop receipts that the backup does
    // not contain so nothing stale survives.
    for (final name in await receipts.listReceipts()) {
      if (content.receipts.containsKey(name)) continue;
      try {
        await receipts.deleteReceiptFile(name);
      } catch (_) {
        // A locked file should not abort the whole restore.
      }
    }
    for (final entry in content.receipts.entries) {
      await receipts.writeReceipt(entry.key, entry.value);
    }
  }

  String invoicesCsv(
    List<SupplierInvoice> invoices,
    String Function(String supplierId) supplierNameOf,
  ) {
    final buf = StringBuffer('\uFEFF');
    buf.writeln(_row([
      'Supplier',
      'Invoice No',
      'Ref/PO',
      'Description',
      'Invoice Date',
      'Received Date',
      'Due Date',
      'Tax %',
      'Subtotal (GH₵)',
      'Total (GH₵)',
      'Paid (GH₵)',
      'Balance (GH₵)',
      'Status',
      'Payment Method',
      'Paid Date',
      'Notes',
      'Items',
    ]));
    for (final inv in invoices) {
      buf.writeln(_row([
        supplierNameOf(inv.supplierId),
        inv.invoiceNumber,
        inv.reference,
        inv.description,
        _date(inv.invoiceDate),
        _date(inv.receivedDate),
        _date(inv.dueDate),
        _num(inv.taxRatePercent),
        _pesewas(inv.amountPesewas),
        _pesewas(inv.totalPesewas),
        _pesewas(inv.amountPaidPesewas),
        _pesewas(inv.balancePesewas),
        inv.statusLabel,
        inv.paymentMethod,
        inv.paidDate == null ? '' : _date(inv.paidDate!),
        inv.notes,
        inv.lines.isEmpty ? '' : _items(inv.lines),
      ]));
    }
    return buf.toString();
  }

  String suppliersCsv(List<Supplier> suppliers) {
    final buf = StringBuffer('\uFEFF');
    buf.writeln(_row(['Name', 'Phone', 'Location', 'Notes']));
    for (final s in suppliers) {
      buf.writeln(_row([s.name, s.phone, s.location, s.notes]));
    }
    return buf.toString();
  }

  /// One row per invoice a payment settled, so the file lines up with the
  /// Payments sheet in the workbook.
  String paymentsCsv(
    List<Payment> payments,
    String Function(String invoiceId) invoiceNumberOf,
    String Function(String invoiceId) supplierNameOf,
  ) {
    final buf = StringBuffer('\uFEFF');
    buf.writeln(_row([
      'Date',
      'Supplier',
      'Invoice No',
      'Amount (GH₵)',
      'Method',
      'Reference',
      'Note',
      'Opening balance',
    ]));
    for (final p in payments) {
      for (final a in p.allocations) {
        buf.writeln(_row([
          _date(p.date),
          supplierNameOf(a.invoiceId),
          invoiceNumberOf(a.invoiceId),
          _pesewas(a.amountPesewas),
          p.method,
          p.reference,
          p.notes,
          p.isLegacy ? 'Yes' : 'No',
        ]));
      }
    }
    return buf.toString();
  }

  String productsCsv(List<Product> products) {
    final buf = StringBuffer('\uFEFF');
    buf.writeln(_row([
      'Product',
      'Pieces per box',
      'Price per box (GH₵)',
      'Notes',
    ]));
    for (final p in products) {
      buf.writeln(_row([
        p.name,
        '${p.piecesPerBox}',
        _pesewas(p.pricePerBoxPesewas),
        p.notes,
      ]));
    }
    return buf.toString();
  }
}

String _date(DateTime d) => DateFormat('dd/MM/yyyy').format(d);
String _num(double v) => v.toStringAsFixed(2).replaceFirst(RegExp(r'\.00$'), '');
String _pesewas(int v) => (v / 100).toStringAsFixed(2);

String _items(List<InvoiceLine> lines) => lines
    .map((l) =>
        '${l.name}: ${l.boxes} x ${l.piecesPerBox} @ ${_pesewas(l.pricePerBoxPesewas)} = ${_pesewas(l.totalPesewas)}')
    .join('; ');

String _row(List<String> cells) => cells.map(_field).join(',');

String _field(String v) {
  if (v.contains(',') || v.contains('"') || v.contains('\n')) {
    return '"${v.replaceAll('"', '""')}"';
  }
  return v;
}
