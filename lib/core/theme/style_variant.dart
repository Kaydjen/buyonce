import 'package:flutter/material.dart';

import 'app_tokens.dart';
import 'styles/design1.dart';
import 'styles/design2.dart';
import 'styles/design3.dart';
import 'styles/design4.dart';
import 'styles/design5.dart';
import 'styles/design6.dart';
import 'styles/design7.dart';

/// The designs, numbered in the order they were made; none is deleted, so an old one can
/// be looked at again. A new design is a new file in `styles/` (colours, shapes and type
/// together: the only place with raw values) and a new entry here. Debug builds switch
/// between them in Settings.
enum StyleVariant {
  d1('1'),
  d2('2'),
  d3('3'),
  d4('4'),
  d5('5'),
  d6('6'),
  d7('7');

  const StyleVariant(this.label);
  final String label;

  AppTokens tokens(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (this) {
      d1 => dark ? Design1.dark : Design1.light,
      d2 => dark ? Design2.dark : Design2.light,
      d3 => dark ? Design3.dark : Design3.light,
      d4 => dark ? Design4.dark : Design4.light,
      d5 => dark ? Design5.dark : Design5.light,
      d6 => dark ? Design6.dark : Design6.light,
      d7 => dark ? Design7.dark : Design7.light,
    };
  }
}
