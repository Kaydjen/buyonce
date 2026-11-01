enum ThemeChoice { system, light, dark }

/// Text size: follow the phone, or a fixed scale that replaces the phone's own.
enum TextScaleChoice {
  system(null),
  large(1.3),
  larger(1.5);

  const TextScaleChoice(this.factor);

  /// Null = follow the phone.
  final double? factor;
}

/// Personal settings of the user; stored on the device, never shared with a group.
class AppSettings {
  const AppSettings({
    this.autoSendEnabled = true,
    this.autoSendSeconds = defaultAutoSendSeconds,
    this.theme = ThemeChoice.system,
    this.textScale = TextScaleChoice.system,
  });

  static const defaultAutoSendSeconds = 3600;

  /// The periods offered in Settings (seconds); 30 s is there in every build.
  static const autoSendPeriods = [30, 300, 600, 900, 1800, 2700, 3600, 7200];

  final bool autoSendEnabled;
  final int autoSendSeconds;
  final ThemeChoice theme;
  final TextScaleChoice textScale;

  AppSettings copyWith({
    bool? autoSendEnabled,
    int? autoSendSeconds,
    ThemeChoice? theme,
    TextScaleChoice? textScale,
  }) => AppSettings(
    autoSendEnabled: autoSendEnabled ?? this.autoSendEnabled,
    autoSendSeconds: autoSendSeconds ?? this.autoSendSeconds,
    theme: theme ?? this.theme,
    textScale: textScale ?? this.textScale,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.autoSendEnabled == autoSendEnabled &&
      other.autoSendSeconds == autoSendSeconds &&
      other.theme == theme &&
      other.textScale == textScale;

  @override
  int get hashCode =>
      Object.hash(autoSendEnabled, autoSendSeconds, theme, textScale);
}
