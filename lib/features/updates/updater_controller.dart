import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'update_service.dart';

class UpdateInstaller {
  Future<void> applyStaged(String stagedDir) async {
    final exe = Platform.resolvedExecutable;
    final appDir = p.dirname(exe);
    final scriptPath = p.join(appDir, 'apply_update.ps1');
    final exeName = p.basenameWithoutExtension(exe);
    final script = '''
Start-Sleep -Milliseconds 800
Stop-Process -Name '$exeName' -Force -ErrorAction SilentlyContinue
Robocopy "$stagedDir" "$appDir" /E /IS /IT /NFL /NDL /NJH /NJS /NC /NS | Out-Null
if (\$LASTEXITCODE -ge 8) { exit \$LASTEXITCODE }
Remove-Item -Recurse -Force "$stagedDir" -ErrorAction SilentlyContinue
Start-Process -FilePath "$exe"
''';
    await File(scriptPath).writeAsString(script);
    await Process.start('powershell.exe', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-WindowStyle',
      'Hidden',
      '-File',
      scriptPath,
    ]);
  }
}

enum UpdaterPhase {
  idle,
  checking,
  upToDate,
  updateAvailable,
  downloading,
  readyToApply,
  applying,
  error,
}

class UpdaterState {
  const UpdaterState({
    this.phase = UpdaterPhase.idle,
    this.downloaded = 0,
    this.total = 0,
    this.version = '',
    this.releaseUrl = '',
    this.error = '',
  });

  final UpdaterPhase phase;
  final int downloaded;
  final int total;
  final String version;
  final String releaseUrl;
  final String error;

  double get progress => total <= 0 ? 0 : downloaded / total;

  UpdaterState copyWith({
    UpdaterPhase? phase,
    int? downloaded,
    int? total,
    String? version,
    String? releaseUrl,
    String? error,
  }) {
    return UpdaterState(
      phase: phase ?? this.phase,
      downloaded: downloaded ?? this.downloaded,
      total: total ?? this.total,
      version: version ?? this.version,
      releaseUrl: releaseUrl ?? this.releaseUrl,
      error: error ?? this.error,
    );
  }
}

class UpdaterController extends StateNotifier<UpdaterState> {
  UpdaterController({
    required UpdateService service,
    required UpdateInstaller installer,
    required String defaultVersion,
  })  : _service = service,
        _installer = installer,
        _defaultVersion = defaultVersion,
        super(const UpdaterState());

  final UpdateService _service;
  final UpdateInstaller _installer;
  final String _defaultVersion;

  UpdateInfo? _info;
  String? _currentVersion;

  Future<String> _currentNormalized() async {
    final v = _currentVersion ??
        _defaultVersion.isEmpty
            ? (await PackageInfo.fromPlatform()).version
            : _defaultVersion;
    _currentVersion = v;
    return UpdateService.normalizeVersion(v);
  }

  Future<void> check() async {
    _info = null;
    state = const UpdaterState(phase: UpdaterPhase.checking);
    final current = await _currentNormalized();
    try {
      final info = await _service.latestRelease();
      if (UpdateService.compareVersions(info.latestVersion, current) <= 0) {
        state = const UpdaterState(phase: UpdaterPhase.upToDate);
      } else {
        _info = info;
        state = UpdaterState(
          phase: UpdaterPhase.updateAvailable,
          version: info.latestVersion,
          releaseUrl: info.releaseUrl,
        );
      }
    } catch (e) {
      state = UpdaterState(
        phase: UpdaterPhase.error,
        error: e is UpdateException
            ? e.message
            : 'Update check failed. Check your internet connection.',
      );
    }
  }

  Future<void> downloadAndInstall() async {
    final info = _info;
    if (info == null || state.phase != UpdaterPhase.updateAvailable) return;
    state = const UpdaterState(phase: UpdaterPhase.downloading);

    final support = await getApplicationSupportDirectory();
    final zipPath = p.join(support.path, 'update_${info.tagName}.zip');
    final stagedRoot = p.join(support.path, 'staged');
    final stagedDir = p.join(stagedRoot, info.latestVersion);
    try {
      await _service.download(
        info.downloadUrl,
        zipPath,
        onProgress: (received, total) {
          state = UpdaterState(
            phase: UpdaterPhase.downloading,
            downloaded: received,
            total: total,
            version: info.latestVersion,
          );
        },
      );
      await _service.extractZip(zipPath, stagedDir);
      state = UpdaterState(phase: UpdaterPhase.readyToApply,
          version: info.latestVersion);
      await _installer.applyStaged(stagedDir);
      state = UpdaterState(phase: UpdaterPhase.applying,
          version: info.latestVersion);
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      await FlutterApp.exit(0);
    } catch (e) {
      state = UpdaterState(
        phase: UpdaterPhase.error,
        error: e is UpdateException
            ? e.message
            : 'Could not install the update.\n\n${info.latestVersion}',
      );
    }
  }
}

final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService(
    repoOwner: 'danielsem65',
    repoName: 'PFA-Pharmacy-Invoice-Tracker',
  );
});

final updaterProvider =
    StateNotifierProvider<UpdaterController, UpdaterState>((ref) {
  return UpdaterController(
    service: ref.watch(updateServiceProvider),
    installer: UpdateInstaller(),
    defaultVersion: '',
  );
});