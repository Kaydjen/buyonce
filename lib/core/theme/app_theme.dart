import 'package:flutter/material.dart';

import 'app_tokens.dart';
import 'style_variant.dart';

/// The only place that maps tokens to `ThemeData`.
abstract final class AppTheme {
  static ThemeData dark([StyleVariant variant = StyleVariant.d7]) =>
      build(variant.tokens(Brightness.dark));

  static ThemeData light([StyleVariant variant = StyleVariant.d7]) =>
      build(variant.tokens(Brightness.light));

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
      titleLarge: base.textTheme.titleLarge?.copyWith(fontSize: t.headingSize),
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
      // The bar keeps the page colour when the content scrolls under it.
      appBarTheme: AppBarTheme(
        backgroundColor: t.background,
        scrolledUnderElevation: 0,
        surfaceTintColor: const Color(0x00000000),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          // Soft styles: no outline; the chosen segment is a raised pill (the track is
          // pressed, see SoftSegments).
          side: WidgetStatePropertyAll(
            t.depth > 0
                ? BorderSide.none
                : BorderSide(color: t.line, width: t.lineWidth),
          ),
          foregroundColor: WidgetStatePropertyAll(t.text),
          shape: t.depth > 0
              ? const WidgetStatePropertyAll(StadiumBorder())
              : null,
          elevation: WidgetStatePropertyAll(t.depth > 0 ? 3 : 0),
          shadowColor: WidgetStatePropertyAll(t.shadowDark ?? t.line),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? (t.depth > 0
                      ? Color.alphaBlend(
                          (t.shadowLight ?? t.surface).withValues(alpha: 0.75),
                          t.surface,
                        )
                      : t.tint)
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
      // Press feedback: no Material ripple. The pressed shape fades to a quiet tint and
      // back, clipped to the control (pills, the card).
      splashFactory: NoSplash.splashFactory,
      splashColor: const Color(0x00000000),
      hoverColor: const Color(0x00000000),
      highlightColor: t.text.withValues(alpha: 0.07),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusButton),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: t.lift ?? t.surface,
        shape: _shape(t, t.radiusCard),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.lift ?? t.surface,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: t.line,
        dragHandleSize: const Size(40, 4),
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
      // The pill is drawn by showToast; this only keeps stray snackbars in the style.
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
            s.copyWith(
              fontFamily: t.displayFamily ?? t.fontFamily,
              letterSpacing: t.titleSpacing,
            ),
            t.titleWeight,
          );
    TextStyle? body(TextStyle? s, [FontWeight? weight]) => s == null
        ? null
        : t.weighted(
            s.copyWith(fontFamily: t.fontFamily, letterSpacing: t.bodySpacing),
            weight ?? t.bodyWeight,
          );
    TextStyle? control(TextStyle? s) =>
        s == null || t.displayOnControls ? title(s) : body(s, t.titleWeight);
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
      labelLarge: control(x.labelLarge),
      labelMedium: control(x.labelMedium),
      labelSmall: control(x.labelSmall),
    );
  }
}
