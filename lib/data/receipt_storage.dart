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

  /// Builds the on-disk name a receipt will get. Callers can reserve a name
  /// up front and only copy the file once the user actually saves.
  String newReceiptName(String sourcePath) {
    return '${DateTime.now().microsecondsSinceEpoch}_${sanitizeName(sourcePath)}';
  }

  Future<String> saveReceiptFile(String sourcePath) async {
    final stored = newReceiptName(sourcePath);
    return copyReceiptAs(sourcePath, stored);
  }

  /// Copies [sourcePath] into the receipts folder under [storedName].
  Future<String> copyReceiptAs(String sourcePath, String storedName) async {
    final dir = await _receiptsDir();
    await File(sourcePath).copy(p.join(dir.path, storedName));
    return storedName;
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

  /// Every receipt currently on disk, by stored name.
  Future<List<String>> listReceipts() async {
    final dir = await _receiptsDir();
    if (!await dir.exists()) return [];
    final names = <String>[];
    await for (final entity in dir.list()) {
      if (entity is File) names.add(p.basename(entity.path));
    }
    return names;
  }

  Future<void> deleteAll() async {
    final dir = await _receiptsDir();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
