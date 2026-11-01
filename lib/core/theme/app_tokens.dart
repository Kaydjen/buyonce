import 'package:flutter/material.dart';

/// Every colour, radius and spacing value the screens use. Screens read it through
/// `context.tokens`; the values live in `palette.dart`, the mapping to `ThemeData` in
/// `app_theme.dart`.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.tint,
    required this.line,
    required this.text,
    required this.muted,
    required this.accent,
    required this.onAccent,
    this.radiusChip = 16,
    this.radiusField = 12,
    this.gutter = 16,
  });

  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color tint;
  final Color line;
  final Color text;

  /// Secondary text; at least 4.5:1 on [tint], so taken rows stay readable.
  final Color muted;

  /// The single accent: the "taken" check and the Send button.
  final Color accent;
  final Color onAccent;

  final double radiusChip;
  final double radiusField;

  /// Side padding of screens.
  final double gutter;

  @override
  AppTokens copyWith({
    Brightness? brightness,
    Color? background,
    Color? surface,
    Color? tint,
    Color? line,
    Color? text,
    Color? muted,
    Color? accent,
    Color? onAccent,
    double? radiusChip,
    double? radiusField,
    double? gutter,
  }) => AppTokens(
    brightness: brightness ?? this.brightness,
    background: background ?? this.background,
    surface: surface ?? this.surface,
    tint: tint ?? this.tint,
    line: line ?? this.line,
    text: text ?? this.text,
    muted: muted ?? this.muted,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    radiusChip: radiusChip ?? this.radiusChip,
    radiusField: radiusField ?? this.radiusField,
    gutter: gutter ?? this.gutter,
  );

  @override
  AppTokens lerp(AppTokens? other, double t) {
    if (other == null) return this;
    return AppTokens(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      tint: Color.lerp(tint, other.tint, t)!,
      line: Color.lerp(line, other.line, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      radiusChip: radiusChip,
      radiusField: radiusField,
      gutter: gutter,
    );
  }
}

extension AppTokensContext on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
