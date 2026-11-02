import 'package:buyonce/core/theme/app_theme.dart';
import 'package:buyonce/core/theme/style_variant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart' show openMenu, pumpApp;

void main() {
  test('no style brings back the Material ripple', () {
    for (final variant in StyleVariant.values) {
      for (final theme in [AppTheme.light(variant), AppTheme.dark(variant)]) {
        expect(theme.splashFactory, NoSplash.splashFactory);
        expect(theme.splashColor, const Color(0x00000000));
        expect(theme.listTileTheme.shape, isA<RoundedRectangleBorder>());
      }
    }
  });

  testWidgets('a pressed Settings row draws no splash, only the tint', (
    tester,
  ) async {
    await pumpApp(tester);
    await openMenu(tester, 'Settings');
    for (final key in ['autoSendSwitch', 'autoSendPeriod']) {
      final row = find.byKey(Key(key));
      final theme = Theme.of(tester.element(row));
      expect(theme.splashFactory, NoSplash.splashFactory);

      final press = await tester.startGesture(tester.getCenter(row));
      await tester.pump(const Duration(milliseconds: 150));
      await press.up();
      await tester.pumpAndSettle();
    }
  });
}
