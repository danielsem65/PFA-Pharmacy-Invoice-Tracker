import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final receiptStorageProvider =
    Provider<ReceiptStorage>((ref) => ReceiptStorage());

class ReceiptStorage {
  Future<Directory> _receiptsDir() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'receipts'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String sanitizeName(String sourcePath) {
    final base = p.basenameWithoutExtension(sourcePath);
    final ext = p.extension(sourcePath);
    final cleaned = base.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return '$cleaned$ext';
  }

  Future<String> saveReceiptFile(String sourcePath) async {
    final dir = await _receiptsDir();
    final stored =
        '${DateTime.now().millisecondsSinceEpoch}_${sanitizeName(sourcePath)}';
    await File(sourcePath).copy(p.join(dir.path, stored));
    return stored;
  }

  Future<String> receiptPath(String storedName) async {
    final dir = await _receiptsDir();
    return p.join(dir.path, storedName);
  }

  Future<List<int>> readReceipt(String storedName) async {
    final path = await receiptPath(storedName);
    if (!await File(path).exists()) {
      throw FileSystemException('Receipt not found', path);
    }
    return File(path).readAsBytes();
  }

  Future<void> writeReceipt(String storedName, List<int> bytes) async {
    final dir = await _receiptsDir();
    await File(p.join(dir.path, storedName)).writeAsBytes(bytes);
  }

  Future<void> deleteReceiptFile(String storedName) async {
    final path = await receiptPath(storedName);
    if (await File(path).exists()) {
      await File(path).delete();
    }
  }

  Future<void> deleteAll() async {
    final dir = await _receiptsDir();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}