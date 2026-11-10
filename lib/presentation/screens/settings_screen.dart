import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_info.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/style_variant.dart';
import '../../core/utils/result.dart';
import '../../data/repositories/gemini_key_repository.dart';
import '../../domain/models/app_settings.dart';
import '../../l10n/l10n.dart';
import '../view_models/settings/gemini_key_view_model.dart';
import '../view_models/settings/settings_view_model.dart';
import '../view_models/settings/style_variant_view_model.dart';
import '../widgets/account_section.dart';
import '../widgets/card_action.dart';
import '../widgets/card_dialog.dart';
import '../widgets/card_sheet.dart';
import '../widgets/edge_fade.dart';
import '../widgets/groove.dart';
import '../widgets/group_dialogs.dart';
import '../widgets/segment_choice.dart';
import '../widgets/soft_switch_tile.dart';
import '../widgets/titled_card.dart';
import '../widgets/version_row.dart';

/// "30 s", "5 min".
String periodLabel(BuildContext context, int seconds) => seconds < 60
    ? context.l10n.secondsShort(seconds)
    : context.l10n.minutesShort(seconds ~/ 60);

/// The value of a row that opens a picker: a raised pill, dimmed while the row is off.
class _ValuePill extends StatelessWidget {
  const _ValuePill({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  /// The same low raised plate as "Mark all" in the list cards.
  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: IgnorePointer(
        ignoring: !enabled,
        // The plate keeps a gap to its touch area; shift it so its right edge lines up
        // with the switch above.
        child: Transform.translate(
          offset: const Offset(12, 0),
          child: CardTextAction(label: label, onPressed: onPressed),
        ),
      ),
    );
  }
}

/// Settings > Gemini: the user's own API key (masked once set) and, when there is one,
/// a way to remove it.
class _GeminiRows extends StatelessWidget {
  const _GeminiRows({
    required this.apiKey,
    required this.onEdit,
    required this.onClear,
  });

  final String? apiKey;
  final VoidCallback onEdit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final key = apiKey;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          key: const Key('apiKeyRow'),
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.apiKey),
          trailing: _ValuePill(
            label: key == null ? context.l10n.add : maskedKey(key),
            enabled: true,
            onPressed: onEdit,
          ),
          onTap: onEdit,
        ),
        if (key != null) ...[
          const Groove(),
          TextButton(
            key: const Key('apiKeyRemove'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 48),
              alignment: Alignment.centerLeft,
            ),
            onPressed: onClear,
            child: Text(context.l10n.remove),
          ),
        ],
      ],
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
      appBar: AppBar(title: Text(context.l10n.settings)),
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
                title: context.l10n.sending,
                padding: _inner,
                child: Column(
                  children: [
                    SoftSwitchTile(
                      key: const Key('autoSendSwitch'),
                      title: context.l10n.autoSend,
                      value: settings.autoSendEnabled,
                      onChanged: vm.setAutoSendEnabled,
                    ),
                    ListTile(
                      key: const Key('autoSendPeriod'),
                      contentPadding: EdgeInsets.zero,
                      enabled: settings.autoSendEnabled,
                      title: Text(context.l10n.sendAfter),
                      trailing: _ValuePill(
                        label: periodLabel(context, settings.autoSendSeconds),
                        enabled: settings.autoSendEnabled,
                        onPressed: () =>
                            _pickPeriod(context, vm, settings.autoSendSeconds),
                      ),
                      onTap: () =>
                          _pickPeriod(context, vm, settings.autoSendSeconds),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TitledCard(
                title: context.l10n.theme,
                padding: _segmentsPad,
                child: SegmentChoice<ThemeChoice>(
                  key: const Key('themeSelector'),
                  options: [
                    for (final t in ThemeChoice.values)
                      SegmentOption(t, Text(_themeName(context, t))),
                  ],
                  selected: settings.theme,
                  onChanged: vm.setTheme,
                ),
              ),
              const SizedBox(height: 16),
              TitledCard(
                title: context.l10n.language,
                padding: _segmentsPad,
                child: SegmentChoice<LanguageChoice>(
                  key: const Key('languageSelector'),
                  options: [
                    SegmentOption(
                      LanguageChoice.system,
                      Text(context.l10n.system),
                    ),
                    // A language is always written in itself.
                    const SegmentOption(LanguageChoice.en, Text('English')),
                    const SegmentOption(LanguageChoice.uk, Text('Українська')),
                  ],
                  selected: settings.language,
                  onChanged: vm.setLanguage,
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
                title: context.l10n.textSize,
                padding: _segmentsPad,
                child: SegmentChoice<TextScaleChoice>(
                  key: const Key('textScaleSelector'),
                  options: [
                    for (final c in TextScaleChoice.values)
                      SegmentOption(
                        c,
                        // Each option is drawn at its own size.
                        c.factor == null
                            ? Text(context.l10n.system)
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
              TitledCard(
                title: context.l10n.gemini,
                padding: _inner,
                child: _GeminiRows(
                  apiKey: ref.watch(geminiKeyProvider).value,
                  onEdit: () => _editKey(context, ref),
                  onClear: ref.read(geminiKeyProvider.notifier).clear,
                ),
              ),
              const SizedBox(height: 16),
              TitledCard(
                title: context.l10n.account,
                padding: _inner,
                child: const AccountSection(),
              ),
              const SizedBox(height: 16),
              TitledCard(
                title: context.l10n.about,
                padding: _inner,
                child: Column(
                  children: [
                    const VersionRow(),
                    ListTile(
                      key: const Key('licensesRow'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.l10n.licenses),
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: 'BuyOnce',
                        applicationVersion: appVersion,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editKey(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return showCardDialog<void>(
      context,
      builder: (_) => PromptDialog(
        title: l10n.apiKey,
        hint: l10n.apiKey,
        confirm: l10n.save,
        plain: true,
        onSubmit: (text) async =>
            switch (await ref.read(geminiKeyProvider.notifier).save(text)) {
              Ok() => null,
              Failure(error: GeminiKeyError.invalid) => l10n.invalidApiKey,
              Failure() => l10n.somethingWrong,
            },
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
              title: Text(periodLabel(context, seconds)),
              trailing: seconds == current ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop(seconds),
            ),
        ],
      ),
    );
    if (picked != null) await vm.setAutoSendSeconds(picked);
  }

  String _themeName(BuildContext context, ThemeChoice theme) => switch (theme) {
    ThemeChoice.system => context.l10n.system,
    ThemeChoice.light => context.l10n.light,
    ThemeChoice.dark => context.l10n.dark,
  };
}
