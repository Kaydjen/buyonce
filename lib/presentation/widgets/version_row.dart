import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../l10n/l10n.dart';
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
        title: Text(context.l10n.version),
        trailing: Text(update.currentVersion, style: muted),
      ),
      UpdateStatus.available => ListTile(
        key: const Key('versionRow'),
        contentPadding: EdgeInsets.zero,
        title: _line(context.l10n.updateTo(version)),
        trailing: _fit(
          FilledButton(
            key: const Key('updateDownload'),
            onPressed: vm.download,
            child: Text(context.l10n.download),
          ),
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
        title: _line(context.l10n.updateTo(version)),
        trailing: _fit(
          TextButton(
            key: const Key('updateRetry'),
            onPressed: vm.download,
            child: Text(context.l10n.retry),
          ),
        ),
      ),
      UpdateStatus.ready => ListTile(
        key: const Key('versionRow'),
        contentPadding: EdgeInsets.zero,
        title: _line(context.l10n.updateTo(version)),
        trailing: _fit(
          FilledButton(
            key: const Key('updateInstall'),
            onPressed: vm.install,
            child: Text(context.l10n.install),
          ),
        ),
      ),
    };
  }
}

/// A button beside a long title: it shrinks instead of squeezing the title out.
Widget _fit(Widget button) => ConstrainedBox(
  constraints: const BoxConstraints(maxWidth: 150),
  child: FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerRight,
    child: button,
  ),
);

/// One line that shrinks to the room left beside the button.
Widget _line(String text) => FittedBox(
  fit: BoxFit.scaleDown,
  alignment: Alignment.centerLeft,
  child: Text(text),
);
