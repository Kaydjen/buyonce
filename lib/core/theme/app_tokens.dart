import 'dart:ui' show lerpDouble;

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
    required this.needMark,
    this.lift,
    this.radiusChip = 16,
    this.radiusField = 12,
    this.radiusCard = 14,
    this.radiusRow = 0,
    this.inset = 0,
    this.pillTabs = false,
    this.radiusButton = 999,
    this.gutter = 16,
    this.rowPad = 8,
    this.lineWidth = 1,
    this.barWidth = 4,
    this.tabBarWidth = 3,
    this.cardOutline = false,
    this.glow = 0,
    this.fontFamily,
    this.titleWeight = FontWeight.w500,
    this.bodyWeight = FontWeight.w400,
    this.titleSpacing = 0,
    this.bodySpacing = 0,
    this.labelSpacing = 0.6,
    this.capsTitles = false,
  });

  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color tint;
  final Color line;
  final Color text;

  /// Secondary text; at least 4.5:1 on [tint], so taken rows stay readable.
  final Color muted;

  /// The single accent: the Send button (checks carry no accent).
  final Color accent;
  final Color onAccent;

  /// The mark of a needed product in Plan; stage 2 decides between text and accent.
  final Color needMark;

  /// Lighter corner of a card's gradient; null = flat [surface].
  final Color? lift;

  final double radiusChip;
  final double radiusField;

  final double radiusCard;

  /// Corner radius of a tinted (taken) row; rows are inset by [inset] so it shows.
  final double radiusRow;
  final double inset;

  /// The bottom switcher is a floating pill, the header band a rounded card.
  final bool pillTabs;
  final double radiusButton;

  /// Side padding of screens.
  final double gutter;

  /// Vertical padding inside a product row.
  final double rowPad;

  /// Thickness of dividers and outlines.
  final double lineWidth;

  /// Thickness of the needed-product bar and of the selected-tab bar.
  final double barWidth;
  final double tabBarWidth;

  /// Shop cards get an outline in [line].
  final bool cardOutline;

  /// Blur radius of the halo around the accent button; 0 = none.
  final double glow;

  /// Bundled variable font (weight axis); null = the platform font.
  final String? fontFamily;
  final FontWeight titleWeight;
  final FontWeight bodyWeight;
  final double titleSpacing;
  final double bodySpacing;

  /// Letter spacing of the small upper-case section labels.
  final double labelSpacing;

  /// Card titles are upper case.
  final bool capsTitles;

  /// [style] in weight [w]; with the bundled font the weight axis is set too.
  TextStyle weighted(TextStyle style, FontWeight w) => style.copyWith(
    fontWeight: w,
    fontVariations: fontFamily == null
        ? null
        : [FontVariation('wght', w.value.toDouble())],
  );

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
    Color? needMark,
    Color? lift,
    double? radiusChip,
    double? radiusField,
    double? radiusCard,
    double? radiusRow,
    double? inset,
    bool? pillTabs,
    double? radiusButton,
    double? gutter,
    double? rowPad,
    double? lineWidth,
    double? barWidth,
    double? tabBarWidth,
    bool? cardOutline,
    double? glow,
    String? fontFamily,
    FontWeight? titleWeight,
    FontWeight? bodyWeight,
    double? titleSpacing,
    double? bodySpacing,
    double? labelSpacing,
    bool? capsTitles,
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
    needMark: needMark ?? this.needMark,
    lift: lift ?? this.lift,
    radiusChip: radiusChip ?? this.radiusChip,
    radiusField: radiusField ?? this.radiusField,
    radiusCard: radiusCard ?? this.radiusCard,
    radiusRow: radiusRow ?? this.radiusRow,
    inset: inset ?? this.inset,
    pillTabs: pillTabs ?? this.pillTabs,
    radiusButton: radiusButton ?? this.radiusButton,
    gutter: gutter ?? this.gutter,
    rowPad: rowPad ?? this.rowPad,
    lineWidth: lineWidth ?? this.lineWidth,
    barWidth: barWidth ?? this.barWidth,
    tabBarWidth: tabBarWidth ?? this.tabBarWidth,
    cardOutline: cardOutline ?? this.cardOutline,
    glow: glow ?? this.glow,
    fontFamily: fontFamily ?? this.fontFamily,
    titleWeight: titleWeight ?? this.titleWeight,
    bodyWeight: bodyWeight ?? this.bodyWeight,
    titleSpacing: titleSpacing ?? this.titleSpacing,
    bodySpacing: bodySpacing ?? this.bodySpacing,
    labelSpacing: labelSpacing ?? this.labelSpacing,
    capsTitles: capsTitles ?? this.capsTitles,
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
      needMark: Color.lerp(needMark, other.needMark, t)!,
      lift: Color.lerp(lift, other.lift, t),
      radiusChip: lerpDouble(radiusChip, other.radiusChip, t)!,
      radiusField: lerpDouble(radiusField, other.radiusField, t)!,
      radiusCard: lerpDouble(radiusCard, other.radiusCard, t)!,
      radiusRow: lerpDouble(radiusRow, other.radiusRow, t)!,
      inset: lerpDouble(inset, other.inset, t)!,
      pillTabs: t < 0.5 ? pillTabs : other.pillTabs,
      radiusButton: lerpDouble(radiusButton, other.radiusButton, t)!,
      gutter: lerpDouble(gutter, other.gutter, t)!,
      rowPad: lerpDouble(rowPad, other.rowPad, t)!,
      lineWidth: lerpDouble(lineWidth, other.lineWidth, t)!,
      barWidth: lerpDouble(barWidth, other.barWidth, t)!,
      tabBarWidth: lerpDouble(tabBarWidth, other.tabBarWidth, t)!,
      cardOutline: t < 0.5 ? cardOutline : other.cardOutline,
      glow: lerpDouble(glow, other.glow, t)!,
      fontFamily: t < 0.5 ? fontFamily : other.fontFamily,
      titleWeight: FontWeight.lerp(titleWeight, other.titleWeight, t)!,
      bodyWeight: FontWeight.lerp(bodyWeight, other.bodyWeight, t)!,
      titleSpacing: lerpDouble(titleSpacing, other.titleSpacing, t)!,
      bodySpacing: lerpDouble(bodySpacing, other.bodySpacing, t)!,
      labelSpacing: lerpDouble(labelSpacing, other.labelSpacing, t)!,
      capsTitles: t < 0.5 ? capsTitles : other.capsTitles,
    );
  }
}

extension AppTokensContext on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
