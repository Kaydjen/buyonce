import 'package:flutter/material.dart';

import 'app_tokens.dart';
import 'style_variant.dart';

/// The only file with raw colour values: edit it to restyle the app. Only
/// `app_theme.dart` may import it; screens use `context.tokens`.
///
/// Trial v1: midnight black and stardust cream shades, one rose gold accent.
abstract final class Palette {
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
    onAccent: Color(0xFF0B0B0D),
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
    onAccent: Color(0xFFFFFBF5),
    needMark: Color(0xFF19151A),
  );

  /// The colours of [variant]: the base palette with the variant's own overrides.
  static AppTokens colours(StyleVariant variant, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (variant) {
      StyleVariant.base => dark ? Palette.dark : Palette.light,
      StyleVariant.vaulto => dark ? _vaultoDark : _vaultoLight,
    };
  }

  // Near-black with a faint grey lift; the accent is a muted copper.
  static const _vaultoDark = AppTokens(
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
  );

  static const _vaultoLight = AppTokens(
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
  );
}
