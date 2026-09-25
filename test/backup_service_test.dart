import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:pfa_pharmacy_invoice_tracker/data/backup_service.dart';

import 'helpers.dart';

void main() {
  test('exportZip/readZip round trips suppliers, invoices and receipts',
      () async {
    final root = Directory.systemTemp.createTempSync('ws');
    addTearDown(() => root.deleteSync(recursive: true));

    final storage = TestReceiptStorage(p.join(root.path, 'receipts'));
    final receiptFile = File(p.join(root.path, 'src_receipt.png'));
    receiptFile.writeAsBytesSync([1, 2, 3, 4, 5]);
    final storedName = await storage.saveReceiptFile(receiptFile.path);

    final store = InMemoryLocalStore(
      suppliers: [supplier('s1', 'Pharma Co')],
      invoices: [
        invoice(
          id: 'i1',
          supplierId: 's1',
          invoiceNumber: 'INV-001',
          amountPesewas: 12000,
          receipts: [storedName],
        ),
      ],
    );

    final service = BackupService(store: store, receipts: storage);
    final zipPath = p.join(root.path, 'backup.zip');
    await service.exportZip(zipPath);

    final content = await service.readZip(zipPath);
    expect(content.suppliers.single.name, 'Pharma Co');
    expect(content.invoices.single.invoiceNumber, 'INV-001');
    expect(content.invoices.single.amountPesewas, 12000);
    expect(content.receipts[storedName], [1, 2, 3, 4, 5]);

    final restoredStore = InMemoryLocalStore();
    final restoredReceipts =
        TestReceiptStorage(p.join(root.path, 'restored'));
    final restoredService =
        BackupService(store: restoredStore, receipts: restoredReceipts);
    await restoredService.importZip(zipPath);

    expect(restoredStore.suppliers.single.name, 'Pharma Co');
    expect(restoredStore.invoices.single.id, 'i1');
    expect(await restoredReceipts.readReceipt(storedName), [1, 2, 3, 4, 5]);
  });

  test('exportZip with invoiceIds exports only those invoices', () async {
    final root = Directory.systemTemp.createTempSync('partial');
    addTearDown(() => root.deleteSync(recursive: true));

    final storage = TestReceiptStorage(p.join(root.path, 'receipts'));
    final receiptIds = <String>[];
    for (var i = 0; i < 2; i++) {
      final file = File(p.join(root.path, 'src_$i.png'));
      file.writeAsBytesSync([i + 1]);
      receiptIds.add(await storage.saveReceiptFile(file.path));
    }

    // Both invoices belong to the same supplier so the referenced-supplier
    // filter keeps the supplier even with a partial export.
    final store = InMemoryLocalStore(
      suppliers: [supplier('s1', 'Pharma Co')],
      invoices: [
        invoice(
          id: 'i1',
          supplierId: 's1',
          invoiceNumber: 'INV-001',
          amountPesewas: 12000,
          receipts: [receiptIds[0]],
        ),
        invoice(
          id: 'i2',
          supplierId: 's1',
          invoiceNumber: 'INV-002',
          amountPesewas: 8000,
          receipts: [receiptIds[1]],
        ),
      ],
    );

    final service = BackupService(store: store, receipts: storage);
    final zipPath = p.join(root.path, 'partial.zip');
    await service.exportZip(zipPath, invoiceIds: {'i1'});

    final content = await service.readZip(zipPath);
    expect(content.invoices.length, 1);
    expect(content.invoices.single.id, 'i1');
    // Shared supplier must be included so the partial backup restores.
    expect(content.suppliers.single.id, 's1');
    expect(content.receipts.keys.toList(), [receiptIds[0]]);
  });

  test('readZip throws FormatException when invoices.json is missing', () async {
    final root = Directory.systemTemp.createTempSync('bad');
    addTearDown(() => root.deleteSync(recursive: true));

    final store = InMemoryLocalStore();
    // Minimal valid-ish archive with only suppliers.json.
    final archive = Archive();
    final bytes = ZipEncoder().encode(archive)!;
    final zipPath = p.join(root.path, 'bad.zip');
    File(zipPath).writeAsBytesSync(bytes);

    final service = BackupService(store: store, receipts: TestReceiptStorage(root.path));
    expect(
      service.readZip(zipPath),
      throwsA(isA<FormatException>()),
    );
  });

  group('CSV export', () {
    test('invoicesCsv includes header, BOM and formatted money', () {
      final service = BackupService(
        store: InMemoryLocalStore(),
        receipts: TestReceiptStorage(Directory.systemTemp.createTempSync('csv').path),
      );
      final csv = service.invoicesCsv(
        [
          invoice(
            id: 'i1',
            supplierId: 's1',
            invoiceNumber: 'INV-001, "quoted"',
            amountPesewas: 123456,
            taxRatePercent: 10,
            description: 'line1\nline2',
            dueDate: DateTime(2001, 3, 5),
          ),
        ],
        (_) => 'Company, Ltd.',
      );

      expect(csv.startsWith('\uFEFF'), isTrue);
      final lines = csv.substring(1).trimRight().split('\n');
      expect(
        lines.first,
        'Supplier,Invoice No,Ref/PO,Description,Invoice Date,Received Date,'
        'Due Date,Tax %,Subtotal (GH₵),Total (GH₵),Paid (GH₵),Balance (GH₵),'
        'Status,Payment Method,Paid Date,Notes',
      );
      expect(csv, contains('"INV-001, ""quoted"""'));
      expect(csv, contains('"line1\nline2"'));
      expect(csv, contains('"Company, Ltd."'));
      expect(csv, contains('1234.56'));
      expect(csv, contains('1358.02'));
    });

    test('suppliersCsv exports supplier rows', () {
      final service = BackupService(
        store: InMemoryLocalStore(),
        receipts: TestReceiptStorage(Directory.systemTemp.createTempSync('csv2').path),
      );
      final csv = service.suppliersCsv([supplier('s1', 'Multi, Pharma')]);
      expect(csv.startsWith('\uFEFF'), isTrue);
      expect(csv, contains('Name,Phone,Location,Notes'));
      expect(csv, contains('"Multi, Pharma"'));
      expect(utf8.decode(utf8.encode(csv.substring(1))), contains('Multi, Pharma'));
    });
  });
}