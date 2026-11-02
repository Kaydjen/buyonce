import 'package:buyonce/core/theme/style_variant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG contrast ratio of two opaque colours.
double _ratio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Text needs 4.5:1; a meaningful non-text mark (the need dot) needs 3:1.
const _textMin = 4.5;
const _markMin = 3.0;

void main() {
  for (final brightness in Brightness.values) {
    final t = StyleVariant.d7.tokens(brightness);
    final name = brightness.name;

    group('design 7 $name', () {
      test('text reads on the page, the card and the tint', () {
        for (final ground in [t.background, t.surface, t.tint]) {
          expect(_ratio(t.text, ground), greaterThanOrEqualTo(_textMin));
        }
      });

      test('muted text reads on the page and the card', () {
        for (final ground in [t.background, t.surface]) {
          expect(_ratio(t.muted, ground), greaterThanOrEqualTo(_textMin));
        }
      });

      test('muted text reads on the tint', () {
        expect(_ratio(t.muted, t.tint), greaterThanOrEqualTo(_textMin));
      });

      test('the grey need dot is seen on the card', () {
        final dot = Color.alphaBlend(
          t.muted.withValues(alpha: 0.75),
          t.surface,
        );
        expect(_ratio(dot, t.surface), greaterThanOrEqualTo(_markMin));
      });
    });
  }
}
