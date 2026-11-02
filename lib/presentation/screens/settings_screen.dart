import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/style_variant.dart';
import '../../domain/models/app_settings.dart';
import '../view_models/settings/settings_view_model.dart';
import '../view_models/settings/style_variant_view_model.dart';
import '../widgets/account_section.dart';
import '../widgets/card_sheet.dart';
import '../widgets/titled_card.dart';
import '../widgets/edge_fade.dart';
import '../widgets/segment_choice.dart';
import '../widgets/soft_switch_tile.dart';
import '../widgets/version_row.dart';

/// "30 s", "5 min".
String periodLabel(int seconds) =>
    seconds < 60 ? '$seconds s' : '${seconds ~/ 60} min';

/// The value of a row that opens a picker: a flat tint pill, dimmed while the row is off.
class _ValuePill extends StatelessWidget {
  const _ValuePill({required this.label, required this.enabled});

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.tint,
          borderRadius: BorderRadius.circular(t.radiusButton),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: t.weighted(
              Theme.of(context).textTheme.labelLarge!.copyWith(color: t.muted),
              t.titleWeight,
            ),
          ),
        ),
      ),
    );
  }
}

/// Personal settings. The sections are filled step by step: for now the rows show the
/// stored values.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _inner = EdgeInsets.symmetric(horizontal: 16);
  static const _segmentsPad = EdgeInsets.fromLTRB(12, 12, 12, 12);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final vm = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      // Short and fixed: a plain scroll view builds every card, so none is missing.
      body: EdgeFade(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            context.tokens.gutter,
            context.tokens.listTopPadding,
            context.tokens.gutter,
            24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TitledCard(
                title: 'Sending',
                padding: _inner,
                child: Column(
                  children: [
                    SoftSwitchTile(
                      key: const Key('autoSendSwitch'),
                      title: 'Auto-send',
                      value: settings.autoSendEnabled,
                      onChanged: vm.setAutoSendEnabled,
                    ),
                    ListTile(
                      key: const Key('autoSendPeriod'),
                      contentPadding: EdgeInsets.zero,
                      enabled: settings.autoSendEnabled,
                      title: const Text('Send after'),
                      trailing: _ValuePill(
                        label: periodLabel(settings.autoSendSeconds),
                        enabled: settings.autoSendEnabled,
                      ),
                      onTap: () =>
                          _pickPeriod(context, vm, settings.autoSendSeconds),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TitledCard(
                title: 'Theme',
                padding: _segmentsPad,
                child: SegmentChoice<ThemeChoice>(
                  key: const Key('themeSelector'),
                  options: [
                    for (final t in ThemeChoice.values)
                      SegmentOption(t, Text(_themeName(t))),
                  ],
                  selected: settings.theme,
                  onChanged: vm.setTheme,
                ),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 16),
                TitledCard(
                  title: 'Style (debug)',
                  padding: _segmentsPad,
                  child: SegmentChoice<StyleVariant>(
                    key: const Key('styleSelector'),
                    options: [
                      for (final v in StyleVariant.values)
                        SegmentOption(v, Text(v.label)),
                    ],
                    selected: ref.watch(styleVariantProvider),
                    onChanged: ref.read(styleVariantProvider.notifier).select,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TitledCard(
                title: 'Text size',
                padding: _segmentsPad,
                child: SegmentChoice<TextScaleChoice>(
                  key: const Key('textScaleSelector'),
                  options: [
                    for (final c in TextScaleChoice.values)
                      SegmentOption(
                        c,
                        // Each option is drawn at its own size.
                        c.factor == null
                            ? const Text('System')
                            : Text(
                                'Aa',
                                textScaler: TextScaler.linear(c.factor!),
                              ),
                      ),
                  ],
                  selected: settings.textScale,
                  onChanged: vm.setTextScale,
                ),
              ),
              const SizedBox(height: 16),
              const TitledCard(
                title: 'Account',
                padding: _inner,
                child: AccountSection(),
              ),
              const SizedBox(height: 16),
              const TitledCard(
                title: 'About',
                padding: _inner,
                child: VersionRow(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickPeriod(
    BuildContext context,
    SettingsViewModel vm,
    int current,
  ) async {
    final picked = await showCardSheet<int>(
      context,
      builder: (context) => SheetCard(
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
    );
    if (picked != null) await vm.setAutoSendSeconds(picked);
  }

  String _themeName(ThemeChoice theme) => switch (theme) {
    ThemeChoice.system => 'System',
    ThemeChoice.light => 'Light',
    ThemeChoice.dark => 'Dark',
  };
}
