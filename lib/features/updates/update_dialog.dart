import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../widgets/glass_dialog.dart';
import 'updater_controller.dart';

Future<void> runUpdateFlow(BuildContext context, WidgetRef ref) async {
  final updater = ref.read(updaterProvider.notifier);
  await updater.check();
  if (!context.mounted) return;
  await showGlassDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _UpdateDialog(),
  );
}

class _UpdateDialog extends ConsumerStatefulWidget {
  const _UpdateDialog();

  @override
  ConsumerState<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<_UpdateDialog> {
  String _currentVersion = '…';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then(
      (info) {
        if (mounted) setState(() => _currentVersion = info.version);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(updaterProvider);
    final texts = Theme.of(context).textTheme;

    return AlertDialog(
      title: const Text('Check for Updates'),
      content: SizedBox(
        width: 400,
        child: switch (state.phase) {
          UpdaterPhase.checking => const _StatusRow(
              child: _RefreshIndicator(),
            ),
          UpdaterPhase.upToDate => Text(
              'You are up to date (${_currentVersion.isEmpty ? '' : 'v$_currentVersion'}).',
            ),
          UpdaterPhase.updateAvailable => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A new version is available.',
                  style: texts.titleMedium,
                ),
                const SizedBox(height: 4),
                Text('Current: v$_currentVersion'),
                Text('Latest:  v${state.version}'),
              ],
            ),
          UpdaterPhase.downloading => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _StatusRow(child: _RefreshIndicator()),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: state.progress),
                const SizedBox(height: 4),
                Text('Downloading… ${(state.progress * 100).round()}%'),
              ],
            ),
          UpdaterPhase.readyToApply ||
          UpdaterPhase.applying =>
            const _StatusRow(
              child: Column(
                children: [
                  SizedBox(width: 24, height: 24, child: _RefreshIndicator()),
                  SizedBox(height: 8),
                  Text('Installing update…'),
                ],
              ),
            ),
          UpdaterPhase.error => Text(state.error),
          UpdaterPhase.idle => const Text('Ready.'),
        },
      ),
      actions: [state.phase == UpdaterPhase.updateAvailable
          ? Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Later'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () =>
                      ref.read(updaterProvider.notifier).downloadAndInstall(),
                  icon: const Icon(Icons.download),
                  label: const Text('Download & Install'),
                ),
              ],
            )
          : (state.phase == UpdaterPhase.idle ||
                  state.phase == UpdaterPhase.upToDate)
              ? TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                )
              : TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                )],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(child: child),
    );
  }
}

class _RefreshIndicator extends StatelessWidget {
  const _RefreshIndicator();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 28,
      height: 28,
      child: CircularProgressIndicator(strokeWidth: 3),
    );
  }
}