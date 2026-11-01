import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../view_models/update/update_view_model.dart';

/// Settings > Version: the installed version, or the stage of an update: available,
/// downloading (with progress), failed (retry), downloaded (install).
class VersionRow extends ConsumerWidget {
  const VersionRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(updateViewModelProvider);
    final vm = ref.read(updateViewModelProvider.notifier);
    final muted = TextStyle(color: context.tokens.muted);
    final version = update.info?.version ?? '';
    return switch (update.status) {
      UpdateStatus.upToDate => ListTile(
        key: const Key('versionRow'),
        contentPadding: EdgeInsets.zero,
        title: const Text('Version'),
        trailing: Text(update.currentVersion, style: muted),
      ),
      UpdateStatus.available => ListTile(
        key: const Key('versionRow'),
        contentPadding: EdgeInsets.zero,
        title: Text('Update to $version'),
        trailing: FilledButton(
          key: const Key('updateDownload'),
          onPressed: vm.download,
          child: const Text('Download'),
        ),
      ),
      UpdateStatus.downloading => ListTile(
        key: const Key('versionRow'),
        contentPadding: EdgeInsets.zero,
        title: LinearProgressIndicator(
          key: const Key('updateProgress'),
          value: update.progress,
        ),
        trailing: Text('${(update.progress * 100).round()}%', style: muted),
      ),
      UpdateStatus.failed => ListTile(
        key: const Key('versionRow'),
        contentPadding: EdgeInsets.zero,
        title: Text('Update to $version'),
        trailing: TextButton(
          key: const Key('updateRetry'),
          onPressed: vm.download,
          child: const Text('Retry'),
        ),
      ),
      UpdateStatus.ready => ListTile(
        key: const Key('versionRow'),
        contentPadding: EdgeInsets.zero,
        title: Text('Update to $version'),
        trailing: FilledButton(
          key: const Key('updateInstall'),
          onPressed: vm.install,
          child: const Text('Install'),
        ),
      ),
    };
  }
}
