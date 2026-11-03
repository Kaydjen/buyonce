import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/result.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../domain/models/app_settings.dart';

/// The settings start as defaults and switch to the stored values when they are read
/// (a few milliseconds, behind the loading screen). A failed read keeps the defaults.
class SettingsViewModel extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    _load();
    return const AppSettings();
  }

  Future<void> _load() async {
    final repository = ref.read(settingsRepositoryProvider);
    final result = await repository.load();
    if (!ref.mounted) return;
    if (result case Ok(:final value)) state = value;
  }

  Future<void> setAutoSendEnabled(bool value) =>
      _update(state.copyWith(autoSendEnabled: value));

  Future<void> setAutoSendSeconds(int seconds) =>
      _update(state.copyWith(autoSendSeconds: seconds));

  Future<void> setTheme(ThemeChoice theme) =>
      _update(state.copyWith(theme: theme));

  Future<void> setTextScale(TextScaleChoice scale) =>
      _update(state.copyWith(textScale: scale));

  Future<void> setLanguage(LanguageChoice language) =>
      _update(state.copyWith(language: language));

  /// The state changes at once; a failed write is ignored (the value lasts until the
  /// app closes).
  Future<void> _update(AppSettings next) async {
    state = next;
    await ref.read(settingsRepositoryProvider).save(next);
  }
}

final settingsProvider = NotifierProvider<SettingsViewModel, AppSettings>(
  SettingsViewModel.new,
);
