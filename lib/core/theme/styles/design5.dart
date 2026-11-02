import 'package:flutter/material.dart';

import '../app_tokens.dart';

/// Design 5: the fourth moodboard (a schedule app). No grey button plates: the top bar
/// is a large tappable heading with the status under it and plain icons; the switcher
/// is a compact levitating pill; panels are flat and quiet, small accents do the work.
/// Accent: amber (orange family only, by the owner's rule). Titles Oswald, the rest Inter.
abstract final class Design5 {
  static const dark = AppTokens(
    brightness: Brightness.dark,
    background: Color(0xFF0A0B0C),
    surface: Color(0xFF141516),
    tint: Color(0xFF1E2022),
    line: Color(0xFF26282B),
    text: Color(0xFFF4F4F5),
    // 5.3:1 on tint.
    muted: Color(0xFF8D9096),
    // 7.8:1 on tint.
    accent: Color(0xFFF0A04B),
    onAccent: Color(0xFF0A0B0C),
    needMark: Color(0xFFF0A04B),
    radiusChip: 999,
    radiusField: 999,
    radiusCard: 24,
    radiusRow: 14,
    radiusButton: 999,
    gutter: 16,
    inset: 6,
    rowPad: 10,
    barWidth: 3,
    pillTabs: true,
    floatTabs: true,
    compactTabs: true,
    floatLift: 60,
    bigHeader: true,
    displayOnControls: false,
    headerTone: false,
    accentFilled: false,
    fontFamily: 'Inter',
    displayFamily: 'Oswald',
    titleWeight: FontWeight.w600,
    bodyWeight: FontWeight.w400,
    titleSpacing: 0.6,
    bodySpacing: -0.1,
    labelSpacing: 1.6,
    capsTitles: true,
  );

  static const light = AppTokens(
    brightness: Brightness.light,
    background: Color(0xFFF3F2F0),
    surface: Color(0xFFFBFAF9),
    tint: Color(0xFFE9E7E4),
    line: Color(0xFFDCD9D5),
    text: Color(0xFF131315),
    // 4.6:1 on tint.
    muted: Color(0xFF656569),
    // 4.4:1 on tint, 5.6:1 on surface: small text sits on surface or background.
    accent: Color(0xFFA34A08),
    onAccent: Color(0xFFFBFAF9),
    needMark: Color(0xFFA34A08),
    radiusChip: 999,
    radiusField: 999,
    radiusCard: 24,
    radiusRow: 14,
    radiusButton: 999,
    gutter: 16,
    inset: 6,
    rowPad: 10,
    barWidth: 3,
    pillTabs: true,
    floatTabs: true,
    compactTabs: true,
    floatLift: 60,
    bigHeader: true,
    displayOnControls: false,
    headerTone: false,
    accentFilled: false,
    fontFamily: 'Inter',
    displayFamily: 'Oswald',
    titleWeight: FontWeight.w600,
    bodyWeight: FontWeight.w400,
    titleSpacing: 0.6,
    bodySpacing: -0.1,
    labelSpacing: 1.6,
    capsTitles: true,
  );
}
