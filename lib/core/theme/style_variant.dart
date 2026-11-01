import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Style directions under trial. Colours of each variant live in `palette.dart`; this
/// file holds the shape and type. Debug builds switch between them in Settings; the
/// winner replaces the others.
enum StyleVariant {
  vaulto('Vaulto'),
  base('Base');

  const StyleVariant(this.label);
  final String label;

  /// [colours] with this variant's shape and type applied.
  AppTokens shape(AppTokens colours) => switch (this) {
    base => colours,
    // Dark glass: rounded cards with a soft gradient and a hairline edge, pill
    // controls, tight Inter, one orange accent.
    vaulto => colours.copyWith(
      radiusChip: 999,
      radiusField: 999,
      radiusCard: 24,
      radiusRow: 16,
      radiusButton: 999,
      gutter: 16,
      inset: 6,
      rowPad: 8,
      lineWidth: 1,
      cardOutline: true,
      pillTabs: true,
      fontFamily: 'Inter',
      titleWeight: FontWeight.w500,
      bodyWeight: FontWeight.w400,
      titleSpacing: -0.4,
      bodySpacing: -0.1,
      labelSpacing: 0.8,
    ),
  };
}
