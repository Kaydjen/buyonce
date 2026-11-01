import 'package:flutter/material.dart';

import 'app_tokens.dart';
import 'palette.dart';

/// The only place that maps tokens to `ThemeData`.
abstract final class AppTheme {
  static ThemeData dark() => build(Palette.dark);

  static ThemeData light() => build(Palette.light);

  static ThemeData build(AppTokens t) {
    final scheme =
        (t.brightness == Brightness.dark
                ? const ColorScheme.dark()
                : const ColorScheme.light())
            .copyWith(
              surface: t.background,
              onSurface: t.text,
              primary: t.text,
              onPrimary: t.background,
              secondaryContainer: t.tint,
              onSecondaryContainer: t.text,
              outline: t.line,
            );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      extensions: [t],
      // Material default sizes, written out because the unlocalized default theme has
      // none. The owner found 18 sp too large (2026-10-31).
      textTheme: base.textTheme.copyWith(
        titleMedium: base.textTheme.titleMedium?.copyWith(fontSize: 16),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 16),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 14),
        bodySmall: base.textTheme.bodySmall?.copyWith(fontSize: 12),
        labelMedium: base.textTheme.labelMedium?.copyWith(fontSize: 14),
        labelLarge: base.textTheme.labelLarge?.copyWith(fontSize: 14),
      ),
      scaffoldBackgroundColor: t.background,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.tint,
        contentTextStyle: base.textTheme.bodyLarge?.copyWith(color: t.text),
        actionTextColor: t.text,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surface,
        hintStyle: TextStyle(color: t.muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(t.radiusField),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
