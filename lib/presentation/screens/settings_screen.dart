import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../domain/models/app_settings.dart';
import '../view_models/settings/settings_view_model.dart';
import '../widgets/account_section.dart';
import '../widgets/section_label.dart';
import '../widgets/version_row.dart';

/// "30 s", "5 min".
String periodLabel(int seconds) =>
    seconds < 60 ? '$seconds s' : '${seconds ~/ 60} min';

/// Personal settings. The sections are filled step by step: for now the rows show the
/// stored values.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final vm = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          context.tokens.gutter,
          8,
          context.tokens.gutter,
          24,
        ),
        children: [
          const SectionLabel('Auto-send'),
          SwitchListTile(
            key: const Key('autoSendSwitch'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-send'),
            value: settings.autoSendEnabled,
            onChanged: vm.setAutoSendEnabled,
          ),
          ListTile(
            key: const Key('autoSendPeriod'),
            contentPadding: EdgeInsets.zero,
            enabled: settings.autoSendEnabled,
            title: const Text('Send after'),
            trailing: Text(
              periodLabel(settings.autoSendSeconds),
              style: TextStyle(
                color: settings.autoSendEnabled
                    ? null
                    : context.tokens.muted.withValues(alpha: 0.5),
              ),
            ),
            onTap: () => _pickPeriod(context, vm, settings.autoSendSeconds),
          ),
          const SectionLabel('Theme'),
          SegmentedButton<ThemeChoice>(
            key: const Key('themeSelector'),
            showSelectedIcon: false,
            segments: [
              for (final t in ThemeChoice.values)
                ButtonSegment(value: t, label: Text(_themeName(t))),
            ],
            selected: {settings.theme},
            onSelectionChanged: (s) => vm.setTheme(s.first),
          ),
          const SectionLabel('Text size'),
          SegmentedButton<TextScaleChoice>(
            key: const Key('textScaleSelector'),
            showSelectedIcon: false,
            segments: [
              for (final c in TextScaleChoice.values)
                ButtonSegment(
                  value: c,
                  // Each option is drawn at its own size.
                  label: c.factor == null
                      ? const Text('System')
                      : Text('Aa', textScaler: TextScaler.linear(c.factor!)),
                ),
            ],
            selected: {settings.textScale},
            onSelectionChanged: (s) => vm.setTextScale(s.first),
          ),
          const SectionLabel('Account'),
          const AccountSection(),
          const SectionLabel('Version'),
          const VersionRow(),
        ],
      ),
    );
  }

  Future<void> _pickPeriod(
    BuildContext context,
    SettingsViewModel vm,
    int current,
  ) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final seconds in AppSettings.autoSendPeriods)
                ListTile(
                  key: Key('period-$seconds'),
                  title: Text(periodLabel(seconds)),
                  trailing: seconds == current ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.of(context).pop(seconds),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) await vm.setAutoSendSeconds(picked);
  }

  String _themeName(ThemeChoice theme) => switch (theme) {
    ThemeChoice.system => 'System',
    ThemeChoice.light => 'Light',
    ThemeChoice.dark => 'Dark',
  };
}
