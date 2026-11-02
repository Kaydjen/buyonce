import 'package:flutter/material.dart';

import '../app_tokens.dart';

/// Design 1: the first trial. Midnight black and stardust cream, rose gold accent, the
/// original square-ish shapes and the platform font. Kept for comparison.
abstract final class Design1 {
  static const dark = AppTokens(
    brightness: Brightness.dark,
    background: Color(0xFF0B0B0D),
    surface: Color(0xFF141416),
    tint: Color(0xFF232226),
    line: Color(0xFF2F2D31),
    text: Color(0xFFF3EBDD),
    // 5.9:1 on tint.
    muted: Color(0xFFA59D99),
    accent: Color(0xFFE2B2A3),
    needMark: Color(0xFFF3EBDD),
  );

  static const light = AppTokens(
    brightness: Brightness.light,
    background: Color(0xFFF6F0E6),
    surface: Color(0xFFFFFBF5),
    tint: Color(0xFFEBE2D6),
    line: Color(0xFFDACFC1),
    text: Color(0xFF19151A),
    // 5.1:1 on tint.
    muted: Color(0xFF675B58),
    accent: Color(0xFF95564C),
    needMark: Color(0xFF19151A),
  );
}
