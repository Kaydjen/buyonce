import 'package:flutter/material.dart';

import 'app_tokens.dart';
import 'palette.dart';
import 'style_variant.dart';

/// The only place that maps tokens to `ThemeData`.
abstract final class AppTheme {
  static ThemeData dark([StyleVariant variant = StyleVariant.vaulto]) =>
      build(variant.shape(Palette.colours(variant, Brightness.dark)));

  static ThemeData light([StyleVariant variant = StyleVariant.vaulto]) =>
      build(variant.shape(Palette.colours(variant, Brightness.light)));

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
    // Material default sizes, written out because the unlocalized default theme has
    // none. The owner found 18 sp too large (2026-10-31).
    var text = base.textTheme.copyWith(
      titleMedium: base.textTheme.titleMedium?.copyWith(fontSize: 16),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 16),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 14),
      bodySmall: base.textTheme.bodySmall?.copyWith(fontSize: 12),
      labelMedium: base.textTheme.labelMedium?.copyWith(fontSize: 14),
      labelLarge: base.textTheme.labelLarge?.copyWith(fontSize: 14),
    );
    if (t.fontFamily != null) text = _typeset(text, t);
    return base.copyWith(
      extensions: [t],
      textTheme: text,
      dividerTheme: DividerThemeData(color: t.line, thickness: t.lineWidth),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStatePropertyAll(
            BorderSide(color: t.line, width: t.lineWidth),
          ),
          foregroundColor: WidgetStatePropertyAll(t.text),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? t.tint
                : const Color(0x00000000),
          ),
        ),
      ),
      // The plain button: a tint plate. Only the Notify button takes the accent.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.tint,
          foregroundColor: t.text,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.radiusButton),
          ),
        ),
      ),
      scaffoldBackgroundColor: t.background,
      popupMenuTheme: PopupMenuThemeData(
        color: t.lift ?? t.surface,
        shape: _shape(t, t.radiusCard),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.lift ?? t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(t.radiusCard),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.lift ?? t.surface,
        shape: _shape(t, t.radiusCard),
      ),
      snackBarTheme: SnackBarThemeData(
        shape: _shape(t, t.radiusField.clamp(0, 20)),
        backgroundColor: t.tint,
        contentTextStyle: base.textTheme.bodyLarge?.copyWith(color: t.text),
        actionTextColor: t.text,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.tint,
        hintStyle: TextStyle(color: t.muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: _fieldBorder(t, t.line),
        enabledBorder: _fieldBorder(t, t.line),
        focusedBorder: _fieldBorder(t, t.muted),
      ),
    );
  }

  static OutlineInputBorder _fieldBorder(AppTokens t, Color color) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(t.radiusField),
        borderSide: t.cardOutline
            ? BorderSide(color: color, width: t.lineWidth)
            : BorderSide.none,
      );

  static RoundedRectangleBorder _shape(AppTokens t, double radius) =>
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: t.cardOutline
            ? BorderSide(color: t.line, width: t.lineWidth)
            : BorderSide.none,
      );

  /// The bundled font, its weights and letter spacing on every text style.
  static TextTheme _typeset(TextTheme x, AppTokens t) {
    TextStyle? title(TextStyle? s) => s == null
        ? null
        : t.weighted(
            s.copyWith(fontFamily: t.fontFamily, letterSpacing: t.titleSpacing),
            t.titleWeight,
          );
    TextStyle? body(TextStyle? s) => s == null
        ? null
        : t.weighted(
            s.copyWith(fontFamily: t.fontFamily, letterSpacing: t.bodySpacing),
            t.bodyWeight,
          );
    return x.copyWith(
      displayLarge: body(x.displayLarge),
      displayMedium: body(x.displayMedium),
      displaySmall: body(x.displaySmall),
      headlineLarge: title(x.headlineLarge),
      headlineMedium: title(x.headlineMedium),
      headlineSmall: title(x.headlineSmall),
      titleLarge: title(x.titleLarge),
      titleMedium: title(x.titleMedium),
      titleSmall: title(x.titleSmall),
      bodyLarge: body(x.bodyLarge),
      bodyMedium: body(x.bodyMedium),
      bodySmall: body(x.bodySmall),
      labelLarge: title(x.labelLarge),
      labelMedium: title(x.labelMedium),
      labelSmall: title(x.labelSmall),
    );
  }
}
