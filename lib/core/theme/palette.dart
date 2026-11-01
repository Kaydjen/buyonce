import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// The only file with raw colour values: edit it to restyle the app. Only
/// `app_theme.dart` may import it; screens use `context.tokens`.
abstract final class Palette {
  static const dark = AppTokens(
    brightness: Brightness.dark,
    background: Color(0xFF111214),
    surface: Color(0xFF1A1C1F),
    tint: Color(0xFF26292E),
    line: Color(0xFF2A2D32),
    text: Color(0xFFE8E9EB),
    // 5.1:1 on tint.
    muted: Color(0xFF9599A0),
    accent: Color(0xFFE8A33D),
    onAccent: Color(0xFF111214),
  );

  /// Provisional until the design of stage 2.
  static const light = AppTokens(
    brightness: Brightness.light,
    background: Color(0xFFF6F6F4),
    surface: Color(0xFFFFFFFF),
    tint: Color(0xFFE9EAEC),
    line: Color(0xFFDADCDF),
    text: Color(0xFF1A1C1F),
    // 5.0:1 on tint.
    muted: Color(0xFF5E636B),
    accent: Color(0xFFA86500),
    onAccent: Color(0xFFFFFFFF),
  );
}
