import 'package:flutter/material.dart';

import 'app_tokens.dart';
import 'styles/design1.dart';
import 'styles/design7.dart';

/// The designs, numbered in the order they were made. Designs 2-6 are archived in
/// `.ai/archive/designs/`; design 1 (flat) stays as the baseline of the widget tests. A new design is a new file in `styles/` (colours, shapes and type
/// together: the only place with raw values) and a new entry here. Debug builds switch
/// between them in Settings.
enum StyleVariant {
  d1('1'),
  d7('7');

  const StyleVariant(this.label);
  final String label;

  AppTokens tokens(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (this) {
      d1 => dark ? Design1.dark : Design1.light,
      d7 => dark ? Design7.dark : Design7.light,
    };
  }
}
