import 'package:flutter/material.dart';

import '../app_tokens.dart';

/// Design 3: the third moodboard (black, condensed heavy headings, tiny orange text).
/// Flat soft panels without an edge, one top bar for both modes, capsules for controls.
/// The accent is a signal orange used only on small things: text, thin lines, the
/// needed-product bar; the Send button is a tint plate with orange text and a thin
/// orange line. Headings are Oswald, everything else Inter.
abstract final class Design3 {
  static const dark = AppTokens(
    brightness: Brightness.dark,
    background: Color(0xFF080808),
    surface: Color(0xFF111111),
    tint: Color(0xFF1C1C1C),
    line: Color(0xFF262626),
    text: Color(0xFFF2F2F2),
    // 5.2:1 on tint.
    muted: Color(0xFF8E8E8E),
    // 5.0:1 on tint.
    accent: Color(0xFFE8601C),
    onAccent: Color(0xFF080808),
    needMark: Color(0xFFE8601C),
    radiusChip: 999,
    radiusField: 999,
    radiusCard: 20,
    radiusRow: 14,
    radiusButton: 999,
    inset: 6,
    rowPad: 10,
    barWidth: 3,
    pillTabs: true,
    headerTone: false,
    accentFilled: false,
    fontFamily: 'Inter',
    displayFamily: 'Oswald',
    titleWeight: FontWeight.w600,
    bodyWeight: FontWeight.w400,
    titleSpacing: 0.6,
    bodySpacing: -0.1,
    labelSpacing: 1.4,
    capsTitles: true,
  );

  static const light = AppTokens(
    brightness: Brightness.light,
    background: Color(0xFFF2F0ED),
    surface: Color(0xFFFAF9F7),
    tint: Color(0xFFE8E6E3),
    line: Color(0xFFDAD7D3),
    text: Color(0xFF121212),
    // 4.6:1 on tint.
    muted: Color(0xFF666666),
    // 4.6:1 on tint.
    accent: Color(0xFFB83A08),
    onAccent: Color(0xFFFAF9F7),
    needMark: Color(0xFFB83A08),
    radiusChip: 999,
    radiusField: 999,
    radiusCard: 20,
    radiusRow: 14,
    radiusButton: 999,
    inset: 6,
    rowPad: 10,
    barWidth: 3,
    pillTabs: true,
    headerTone: false,
    accentFilled: false,
    fontFamily: 'Inter',
    displayFamily: 'Oswald',
    titleWeight: FontWeight.w600,
    bodyWeight: FontWeight.w400,
    titleSpacing: 0.6,
    bodySpacing: -0.1,
    labelSpacing: 1.4,
    capsTitles: true,
  );
}
