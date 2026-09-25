import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

import 'package:pfa_pharmacy_invoice_tracker/features/updates/update_service.dart';

void main() {
  group('version helpers', () {
    test('normalizeVersion strips v prefix and +build suffix', () {
      expect(UpdateService.normalizeVersion('v1.2.3'), '1.2.3');
      expect(UpdateService.normalizeVersion('1.2.3+4'), '1.2.3');
      expect(UpdateService.normalizeVersion('v2.0.0+7'), '2.0.0');
      expect(UpdateService.normalizeVersion(' 1.0.0 '), '1.0.0');
    });

    test('compareVersions orders numeric parts', () {
      expect(UpdateService.compareVersions('1.0.0', '1.0.0'), 0);
      expect(UpdateService.compareVersions('1.0.1', '1.0.0'), 1);
      expect(UpdateService.compareVersions('1.0.0', '1.0.1'), -1);
      expect(UpdateService.compareVersions('1.10.0', '1.9.0'), 1);
      expect(UpdateService.compareVersions('1.2.0', '1.2.0.1'), -1);
    });
  });

  group('latestRelease', () {
    test('parses release and selects the .zip asset', () async {
      final client = MockClient((request) async {
        expect(request.url.path, contains('/releases/latest'));
        expect(request.headers['Accept'], 'application/vnd.github+json');
        return http.Response(
          jsonEncode({
            'tag_name': 'v1.2.3',
            'name': 'v1.2.3',
            'html_url': 'https://github.com/a/b/releases/tag/v1.2.3',
            'assets': [
              {
                'name': 'notes.txt',
                'browser_download_url': 'https://x/y/notes.txt',
              },
              {
                'name': 'PFA-Pharmacy-Invoice-Tracker.zip',
                'browser_download_url': 'https://x/y/app.zip',
              },
            ],
          }),
          200,
        );
      });
      final svc = UpdateService(
        repoOwner: 'danielsem65',
        repoName: 'PFA-Pharmacy-Invoice-Tracker',
        client: client,
      );
      final info = await svc.latestRelease();
      expect(info.latestVersion, '1.2.3');
      expect(info.tagName, 'v1.2.3');
      expect(info.downloadUrl, 'https://x/y/app.zip');
      expect(info.releaseUrl, contains('/releases/tag/v1.2.3'));
    });

    test('throws UpdateException on non-200', () async {
      final client = MockClient((_) async => http.Response('', 404));
      final svc = UpdateService(repoOwner: 'a', repoName: 'b', client: client);
      expect(svc.latestRelease(), throwsA(isA<UpdateException>()));
    });

    test('throws UpdateException when zip asset missing', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'tag_name': 'v1.0.0',
            'assets': <Object>[],
          }),
          200,
        ),
      );
      final svc = UpdateService(repoOwner: 'a', repoName: 'b', client: client);
      expect(svc.latestRelease(), throwsA(isA<UpdateException>()));
    });
  });

  group('download', () {
    test('writes body and reports progress', () async {
      final body = List<int>.generate(1000, (i) => i % 256);
      final client = MockClient((_) async => http.Response.bytes(body, 200));
      final svc = UpdateService(repoOwner: 'a', repoName: 'b', client: client);

      final dir = Directory.systemTemp.createTempSync('dl');
      final target = p.join(dir.path, 'update.zip');
      addTearDown(() => dir.deleteSync(recursive: true));

      var lastReceived = 0;
      var lastTotal = 0;
      var calls = 0;
      await svc.download(
        'https://x/y/app.zip',
        target,
        onProgress: (received, total) {
          calls++;
          lastReceived = received;
          lastTotal = total;
        },
      );
      final bytes = await File(target).readAsBytes();
      expect(bytes.length, body.length);
      expect(lastTotal, body.length);
      expect(lastReceived, body.length);
      expect(calls, greaterThanOrEqualTo(1));
    });
  });

  group('extractZip', () {
    test('extracts files and ignores path traversal', () async {
      final archive = Archive()
        ..addFile(ArchiveFile.string('good/file.txt', 'A'))
        ..addFile(ArchiveFile.string('../evil.txt', 'B'))
        ..addFile(ArchiveFile.string('..\\evil2.txt', 'C'));

      final dir = Directory.systemTemp.createTempSync('zip');
      final zipPath = p.join(dir.path, 'update.zip');
      final outDir = p.join(dir.path, 'out');
      addTearDown(() => dir.deleteSync(recursive: true));

      File(zipPath).writeAsBytesSync(ZipEncoder().encode(archive)!);

      final svc = UpdateService(repoOwner: 'a', repoName: 'b');
      await svc.extractZip(zipPath, outDir);

      expect(
        await File(p.join(outDir, 'good', 'file.txt')).readAsString(),
        'A',
      );
      expect(await File(p.join(outDir, 'evil.txt')).exists(), isFalse);
      expect(await File(p.join(outDir, 'evil2.txt')).exists(), isFalse);
      final parent = Directory(p.dirname(outDir));
      expect(await File(p.join(parent.path, 'evil.txt')).exists(), isFalse);
    });
  });
}