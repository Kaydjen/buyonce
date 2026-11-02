import 'package:flutter/material.dart';

import '../app_tokens.dart';

/// Design 4: design 3 after the owner's remarks. Top bar buttons are plates and the
/// status is plain text with an accent number; the mode switcher is two levitating
/// buttons over a list that fades at the bottom; buttons and tabs are Inter (Oswald
/// stayed on titles only). New accent: a soft mint green.
abstract final class Design4 {
  static const dark = AppTokens(
    brightness: Brightness.dark,
    background: Color(0xFF080808),
    surface: Color(0xFF111111),
    tint: Color(0xFF1C1C1C),
    line: Color(0xFF262626),
    text: Color(0xFFF2F2F2),
    // 5.2:1 on tint.
    muted: Color(0xFF8E8E8E),
    // 7.7:1 on tint.
    accent: Color(0xFF5FBF9F),
    onAccent: Color(0xFF080808),
    needMark: Color(0xFF5FBF9F),
    radiusChip: 999,
    radiusField: 999,
    radiusCard: 20,
    radiusRow: 14,
    radiusButton: 999,
    inset: 6,
    rowPad: 10,
    barWidth: 3,
    pillTabs: true,
    floatTabs: true,
    plateButtons: true,
    displayOnControls: false,
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
    // 4.9:1 on tint.
    accent: Color(0xFF1A6E54),
    onAccent: Color(0xFFFAF9F7),
    needMark: Color(0xFF1A6E54),
    radiusChip: 999,
    radiusField: 999,
    radiusCard: 20,
    radiusRow: 14,
    radiusButton: 999,
    inset: 6,
    rowPad: 10,
    barWidth: 3,
    pillTabs: true,
    floatTabs: true,
    plateButtons: true,
    displayOnControls: false,
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
