import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/result.dart';
import '../../domain/models/app_settings.dart';
import '../services/settings_service.dart';

class SettingsRepository {
  SettingsRepository(this._service);
  final SettingsService _service;

  static const _autoSendEnabled = 'autoSendEnabled';
  static const _autoSendSeconds = 'autoSendSeconds';
  static const _theme = 'theme';
  static const _textScale = 'textScale';
  static const _localMode = 'localMode';

  /// Whether the user chose to use the app without an account; null if never chosen
  /// or unreadable.
  Future<bool?> loadLocalMode() async =>
      switch (await _service.getBool(_localMode)) {
        Ok(:final value) => value,
        Failure() => null,
      };

  Future<Result<void>> saveLocalMode(bool local) =>
      _service.setBool(_localMode, local);

  /// Unreadable or unknown stored values fall back to the defaults.
  Future<Result<AppSettings>> load() async {
    const defaults = AppSettings();
    final enabled = await _service.getBool(_autoSendEnabled);
    final seconds = await _service.getInt(_autoSendSeconds);
    final theme = await _service.getString(_theme);
    final scale = await _service.getString(_textScale);
    for (final r in [enabled, seconds, theme, scale]) {
      if (r case Failure(:final error)) return Failure(error);
    }
    final storedSeconds = (seconds as Ok<int?>).value;
    final storedTheme = (theme as Ok<String?>).value;
    final storedScale = (scale as Ok<String?>).value;
    return Ok(
      AppSettings(
        autoSendEnabled:
            (enabled as Ok<bool?>).value ?? defaults.autoSendEnabled,
        autoSendSeconds: AppSettings.autoSendPeriods.contains(storedSeconds)
            ? storedSeconds!
            : defaults.autoSendSeconds,
        theme: ThemeChoice.values.firstWhere(
          (t) => t.name == storedTheme,
          orElse: () => defaults.theme,
        ),
        textScale: TextScaleChoice.values.firstWhere(
          (t) => t.name == storedScale,
          orElse: () => defaults.textScale,
        ),
      ),
    );
  }

  Future<Result<void>> save(AppSettings settings) async {
    final results = [
      await _service.setBool(_autoSendEnabled, settings.autoSendEnabled),
      await _service.setInt(_autoSendSeconds, settings.autoSendSeconds),
      await _service.setString(_theme, settings.theme.name),
      await _service.setString(_textScale, settings.textScale.name),
    ];
    for (final r in results) {
      if (r case Failure(:final error)) return Failure(error);
    }
    return const Ok(null);
  }
}

final settingsRepositoryProvider = Provider(
  (ref) => SettingsRepository(ref.watch(settingsServiceProvider)),
);
