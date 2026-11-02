import 'package:flutter/material.dart';

import '../app_tokens.dart';

/// Design 2: the first moodboard (Vaulto). Near-black with a faint grey lift, gradient
/// panels with a hairline edge, pills, tight Inter, a muted copper accent. Kept for
/// comparison.
abstract final class Design2 {
  static const dark = AppTokens(
    brightness: Brightness.dark,
    background: Color(0xFF050505),
    surface: Color(0xFF0D0D0E),
    lift: Color(0xFF1B1B1D),
    tint: Color(0xFF202022),
    line: Color(0xFF2A2A2D),
    text: Color(0xFFF5F5F5),
    // 5.8:1 on tint.
    muted: Color(0xFF9A9AA0),
    accent: Color(0xFFC98560),
    onAccent: Color(0xFF0A0A0A),
    needMark: Color(0xFFF5F5F5),
    radiusChip: 999,
    radiusField: 999,
    radiusCard: 24,
    radiusRow: 16,
    radiusButton: 999,
    inset: 6,
    cardOutline: true,
    pillTabs: true,
    fontFamily: 'Inter',
    titleSpacing: -0.4,
    bodySpacing: -0.1,
    labelSpacing: 0.8,
  );

  static const light = AppTokens(
    brightness: Brightness.light,
    background: Color(0xFFF3F2F0),
    surface: Color(0xFFFAFAF9),
    lift: Color(0xFFFFFFFF),
    tint: Color(0xFFE9E7E4),
    line: Color(0xFFDDDAD6),
    text: Color(0xFF111113),
    // 4.6:1 on tint.
    muted: Color(0xFF66666B),
    accent: Color(0xFFA5532E),
    onAccent: Color(0xFFFFFFFF),
    needMark: Color(0xFF111113),
    radiusChip: 999,
    radiusField: 999,
    radiusCard: 24,
    radiusRow: 16,
    radiusButton: 999,
    inset: 6,
    cardOutline: true,
    pillTabs: true,
    fontFamily: 'Inter',
    titleSpacing: -0.4,
    bodySpacing: -0.1,
    labelSpacing: 0.8,
  );
}
