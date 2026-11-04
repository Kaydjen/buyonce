import 'package:buyonce/core/font_license.dart';
import 'package:buyonce/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'Settings > Licenses opens the page with the Montserrat license',
    (tester) async {
      registerFontLicense();
      await tester.pumpWidget(const ProviderScope(child: BuyOnceApp()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menuButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -2000),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('licensesRow')));
      await tester.pumpAndSettle();

      expect(find.byType(LicensePage), findsOneWidget);
      expect(find.text('Montserrat'), findsOneWidget);
    },
  );
}
