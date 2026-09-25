import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class UpdateInfo {
  const UpdateInfo({
    required this.latestVersion,
    required this.tagName,
    required this.releaseName,
    required this.releaseUrl,
    required this.downloadUrl,
  });

  final String latestVersion;
  final String tagName;
  final String releaseName;
  final String releaseUrl;
  final String downloadUrl;
}

class UpdateException implements Exception {
  UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UpdateService {
  UpdateService({
    required this.repoOwner,
    required this.repoName,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String repoOwner;
  final String repoName;
  final http.Client _client;

  static String normalizeVersion(String version) {
    var v = version.trim();
    if (v.startsWith('v')) v = v.substring(1);
    final plus = v.indexOf('+');
    if (plus >= 0) v = v.substring(0, plus);
    return v;
  }

  static int compareVersions(String a, String b) {
    final pa = a.split('.');
    final pb = b.split('.');
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final x = i < pa.length ? int.tryParse(pa[i]) ?? 0 : 0;
      final y = i < pb.length ? int.tryParse(pb[i]) ?? 0 : 0;
      if (x != y) return x < y ? -1 : 1;
    }
    return 0;
  }

  Future<UpdateInfo> latestRelease() async {
    final uri =
        Uri.parse('https://api.github.com/repos/$repoOwner/$repoName/releases/latest');
    final response = await _client.get(uri, headers: {
      'Accept': 'application/vnd.github+json',
      'User-Agent': 'pfa-pharmacy-invoice-tracker',
    });
    if (response.statusCode != 200) {
      throw UpdateException(
        'Update check failed (HTTP ${response.statusCode}).',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final tag = (body['tag_name'] as String?) ?? '';
    if (tag.isEmpty) {
      throw UpdateException('No release found.');
    }
    Map<String, dynamic>? zipAsset;
    for (final asset in (body['assets'] as List<dynamic>?) ?? const []) {
      final map = asset as Map<String, dynamic>;
      if ((map['name'] as String).endsWith('.zip')) {
        zipAsset = map;
        break;
      }
    }
    if (zipAsset == null) {
      throw UpdateException('Release has no archive asset.');
    }
    return UpdateInfo(
      latestVersion: normalizeVersion(tag),
      tagName: tag,
      releaseName: (body['name'] as String?) ?? tag,
      releaseUrl: (body['html_url'] as String?) ?? '',
      downloadUrl: zipAsset['browser_download_url'] as String,
    );
  }

  Future<void> download(
    String url,
    String targetPath, {
    void Function(int received, int total)? onProgress,
  }) async {
    final request = http.Request('GET', Uri.parse(url));
    final streamed = await _client.send(request);
    if (streamed.statusCode != 200) {
      throw UpdateException(
        'Download failed (HTTP ${streamed.statusCode}).',
      );
    }
    final total = streamed.contentLength ?? 0;
    final sink = File(targetPath).openWrite();
    var received = 0;
    try {
      await for (final chunk in streamed.stream) {
        received += chunk.length;
        sink.add(chunk);
        onProgress?.call(received, total);
      }
    } finally {
      await sink.close();
    }
  }

  Future<void> extractZip(String zipPath, String toDir) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final f in archive.files) {
      if (!f.isFile) continue;
      final name = f.name.replaceAll('\\', '/');
      if (name.contains('..') || p.isAbsolute(name)) continue;
      final out = p.join(toDir, name);
      if (!p.isWithin(toDir, out)) continue;
      final dir = p.dirname(out);
      await Directory(dir).create(recursive: true);
      await File(out).writeAsBytes(f.content as List<int>, flush: true);
    }
  }
}