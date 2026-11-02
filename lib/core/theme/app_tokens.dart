import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Every colour, radius and spacing value the screens use. Screens read it through
/// `context.tokens`; the values live in `styles/`, the mapping to `ThemeData` in
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
    this.headerTone = true,
    this.radiusButton = 999,
    this.gutter = 16,
    this.rowPad = 8,
    this.lineWidth = 1,
    this.barWidth = 4,
    this.tabBarWidth = 3,
    this.cardOutline = false,
    this.glow = 0,
    this.accentFilled = true,
    this.floatTabs = false,
    this.plateButtons = false,
    this.displayOnControls = true,
    this.bigHeader = false,
    this.compactTabs = false,
    this.floatLift = 76,
    this.depth = 0,
    this.shadowBlur = 1.8,
    this.needDot = false,
    this.accentAsText = true,
    this.cardButtons = false,
    this.shadowLight,
    this.shadowDark,
    this.accentInk,
    this.statusInline = false,
    this.headingSize = 22,
    this.tabHeight = 36,
    this.captionSpacing,
    this.fontFamily,
    this.displayFamily,
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

  /// The Shop top bar sits on a tint plate that the Plan bar lacks.
  final bool headerTone;
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

  /// The accent button is filled with the accent; otherwise a tint plate with accent
  /// text and a thin accent line.
  final bool accentFilled;

  /// The mode switcher is two levitating buttons over the list, which fades out toward
  /// the bottom edge (needs [pillTabs]).
  final bool floatTabs;

  /// Top bar buttons are tint plates; the status text beside them is not.
  final bool plateButtons;

  /// Buttons, tabs and small labels use [displayFamily]; otherwise [fontFamily].
  final bool displayOnControls;

  /// The top bar is a large tappable heading with plain icons, no buttons.
  final bool bigHeader;

  /// The floating switcher is as wide and as tall as its two tabs.
  final bool compactTabs;

  /// How far the Send button rises above the bottom edge to clear the floating switcher.
  final double floatLift;

  /// Soft-UI depth: the offset of the raised shadows (the blur is 1.8 times that); 0 = flat.
  final double depth;

  /// Blur of a raised shadow as a multiple of its offset.
  final double shadowBlur;

  /// Needed products in Plan carry a glowing dot, not a bar.
  final bool needDot;

  /// The accent may colour text. Off: text stays neutral and the accent shows only as a
  /// small dot (an orange text on a light page is muddy or too faint).
  final bool accentAsText;

  /// Buttons in card titles ("Mark all", search) are small raised plates.
  final bool cardButtons;
  final Color? shadowLight;
  final Color? shadowDark;

  /// The accent where it is text or a thin line on a surface (needs 4.5:1); the accent
  /// itself when null. Fills and bars use [accent].
  final Color? accentInk;
  Color get ink => accentInk ?? accent;

  /// The status of Plan sits right of the heading instead of under it.
  final bool statusInline;

  /// Font size of the heading in the top bar and of app bar titles.
  final double headingSize;

  /// Height of a tab of the compact switcher.
  final double tabHeight;

  /// Letter spacing of card titles; the title spacing when null.
  final double? captionSpacing;

  /// Room above the first card of a scrolling screen, so its soft shadow is not cut by
  /// the top edge of the list (the light one reaches about 2.5 times the depth up).
  double get listTopPadding => depth > 0 ? depth * 3 : 8;

  /// The two soft shadows of a raised shape (light from the top left); none when flat.
  List<BoxShadow> raised([double scale = 1]) {
    final light = shadowLight;
    final dark = shadowDark;
    if (depth == 0 || light == null || dark == null) return const [];
    final d = depth * scale;
    return [
      BoxShadow(
        color: light,
        offset: Offset(-d, -d),
        blurRadius: shadowBlur * d,
      ),
      BoxShadow(color: dark, offset: Offset(d, d), blurRadius: shadowBlur * d),
    ];
  }

  /// [style] of a control (tab, button label) in the family the style wants there.
  TextStyle controlStyle(TextStyle style) =>
      displayOnControls || fontFamily == null
      ? style
      : style.copyWith(fontFamily: fontFamily, letterSpacing: bodySpacing);

  /// Bundled variable font (weight axis); null = the platform font.
  final String? fontFamily;

  /// Family of titles, labels and buttons; [fontFamily] when null.
  final String? displayFamily;
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
    bool? headerTone,
    double? radiusButton,
    double? gutter,
    double? rowPad,
    double? lineWidth,
    double? barWidth,
    double? tabBarWidth,
    bool? cardOutline,
    double? glow,
    bool? accentFilled,
    bool? floatTabs,
    bool? plateButtons,
    bool? displayOnControls,
    bool? bigHeader,
    bool? compactTabs,
    double? floatLift,
    double? depth,
    double? shadowBlur,
    bool? needDot,
    bool? accentAsText,
    bool? cardButtons,
    Color? shadowLight,
    Color? shadowDark,
    Color? accentInk,
    bool? statusInline,
    double? headingSize,
    double? tabHeight,
    double? captionSpacing,
    String? fontFamily,
    String? displayFamily,
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
    headerTone: headerTone ?? this.headerTone,
    radiusButton: radiusButton ?? this.radiusButton,
    gutter: gutter ?? this.gutter,
    rowPad: rowPad ?? this.rowPad,
    lineWidth: lineWidth ?? this.lineWidth,
    barWidth: barWidth ?? this.barWidth,
    tabBarWidth: tabBarWidth ?? this.tabBarWidth,
    cardOutline: cardOutline ?? this.cardOutline,
    glow: glow ?? this.glow,
    accentFilled: accentFilled ?? this.accentFilled,
    floatTabs: floatTabs ?? this.floatTabs,
    plateButtons: plateButtons ?? this.plateButtons,
    displayOnControls: displayOnControls ?? this.displayOnControls,
    bigHeader: bigHeader ?? this.bigHeader,
    compactTabs: compactTabs ?? this.compactTabs,
    floatLift: floatLift ?? this.floatLift,
    depth: depth ?? this.depth,
    shadowBlur: shadowBlur ?? this.shadowBlur,
    needDot: needDot ?? this.needDot,
    accentAsText: accentAsText ?? this.accentAsText,
    cardButtons: cardButtons ?? this.cardButtons,
    shadowLight: shadowLight ?? this.shadowLight,
    shadowDark: shadowDark ?? this.shadowDark,
    accentInk: accentInk ?? this.accentInk,
    statusInline: statusInline ?? this.statusInline,
    headingSize: headingSize ?? this.headingSize,
    tabHeight: tabHeight ?? this.tabHeight,
    captionSpacing: captionSpacing ?? this.captionSpacing,
    fontFamily: fontFamily ?? this.fontFamily,
    displayFamily: displayFamily ?? this.displayFamily,
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
      headerTone: t < 0.5 ? headerTone : other.headerTone,
      radiusButton: lerpDouble(radiusButton, other.radiusButton, t)!,
      gutter: lerpDouble(gutter, other.gutter, t)!,
      rowPad: lerpDouble(rowPad, other.rowPad, t)!,
      lineWidth: lerpDouble(lineWidth, other.lineWidth, t)!,
      barWidth: lerpDouble(barWidth, other.barWidth, t)!,
      tabBarWidth: lerpDouble(tabBarWidth, other.tabBarWidth, t)!,
      cardOutline: t < 0.5 ? cardOutline : other.cardOutline,
      glow: lerpDouble(glow, other.glow, t)!,
      accentFilled: t < 0.5 ? accentFilled : other.accentFilled,
      floatTabs: t < 0.5 ? floatTabs : other.floatTabs,
      plateButtons: t < 0.5 ? plateButtons : other.plateButtons,
      displayOnControls: t < 0.5 ? displayOnControls : other.displayOnControls,
      bigHeader: t < 0.5 ? bigHeader : other.bigHeader,
      compactTabs: t < 0.5 ? compactTabs : other.compactTabs,
      floatLift: lerpDouble(floatLift, other.floatLift, t)!,
      depth: lerpDouble(depth, other.depth, t)!,
      shadowBlur: lerpDouble(shadowBlur, other.shadowBlur, t)!,
      needDot: t < 0.5 ? needDot : other.needDot,
      accentAsText: t < 0.5 ? accentAsText : other.accentAsText,
      cardButtons: t < 0.5 ? cardButtons : other.cardButtons,
      shadowLight: Color.lerp(shadowLight, other.shadowLight, t),
      shadowDark: Color.lerp(shadowDark, other.shadowDark, t),
      accentInk: Color.lerp(accentInk, other.accentInk, t),
      statusInline: t < 0.5 ? statusInline : other.statusInline,
      headingSize: lerpDouble(headingSize, other.headingSize, t)!,
      tabHeight: lerpDouble(tabHeight, other.tabHeight, t)!,
      captionSpacing: lerpDouble(captionSpacing, other.captionSpacing, t),
      fontFamily: t < 0.5 ? fontFamily : other.fontFamily,
      displayFamily: t < 0.5 ? displayFamily : other.displayFamily,
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
