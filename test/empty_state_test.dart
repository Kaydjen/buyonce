import 'package:buyonce/core/theme/style_variant.dart';
import 'package:buyonce/presentation/view_models/settings/style_variant_view_model.dart';
import 'package:buyonce/presentation/widgets/product_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'groups_ui_test.dart'
    show containerOf, createGroup, openSheet, pumpApp, tapText;

/// Both looks: the flat design 1 of the tests and the soft design 7 of the app.
const _looks = [StyleVariant.d1, StyleVariant.d7];

Future<void> _look(WidgetTester tester, StyleVariant variant) async {
  containerOf(tester).read(styleVariantProvider.notifier).select(variant);
  await tester.pumpAndSettle();
}

Future<void> _tab(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> _newGroup(WidgetTester tester) async {
  await openSheet(tester);
  await tapText(tester, 'New group');
  await createGroup(tester, 'Cabin');
}

void main() {
  for (final look in _looks) {
    group('empty list, ${look.name}', () {
      testWidgets('Shop: the empty Frequent card offers Add products', (
        tester,
      ) async {
        await pumpApp(tester, seed: false);
        await _look(tester, look);
        expect(find.byType(ProductRow), findsNothing);
        expect(find.byKey(const Key('emptyAdd')), findsOneWidget);

        await tester.tap(find.byKey(const Key('emptyAdd')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('draftField')), findsOneWidget);
      });

      testWidgets('Plan: the empty Select card offers Add products', (
        tester,
      ) async {
        await pumpApp(tester, seed: false);
        await _look(tester, look);
        await _tab(tester, 'tabPlan');
        expect(find.byKey(const Key('emptyAdd')), findsOneWidget);
      });

      testWidgets('a new group is empty in both modes', (tester) async {
        await pumpApp(tester);
        await _look(tester, look);
        await _newGroup(tester);
        expect(find.byKey(const Key('emptyAdd')), findsOneWidget);
        await _tab(tester, 'tabPlan');
        expect(find.byKey(const Key('emptyAdd')), findsOneWidget);
      });

      testWidgets('the button goes while searching; Add "x" takes its place', (
        tester,
      ) async {
        await pumpApp(tester, seed: false);
        await _look(tester, look);
        await _tab(tester, 'tabPlan');
        await tester.tap(find.byKey(const Key('findButton')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('emptyAdd')), findsNothing);

        await tester.enterText(find.byKey(const Key('addField')), 'Nuts');
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('emptyAdd')), findsNothing);
        expect(find.byKey(const Key('addNew')), findsOneWidget);
        expect(find.text('Add "Nuts"'), findsOneWidget);

        await tester.tap(find.byKey(const Key('addNew')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('addNew')), findsNothing);
        expect(find.byKey(const Key('emptyAdd')), findsNothing);
        expect(find.byType(ProductRow), findsOneWidget);
      });

      testWidgets('the bulk add in Shop makes products needed, not taken', (
        tester,
      ) async {
        await pumpApp(tester, seed: false);
        await _look(tester, look);
        await tester.tap(find.byKey(const Key('emptyAdd')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('draftField')), 'Pears');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('addCommit')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('toBuyCard')), findsOneWidget);
        expect(find.byKey(const Key('emptyAdd')), findsNothing);
        // Nothing is marked: no Send button yet.
        expect(find.byKey(const Key('sendButton')).hitTestable(), findsNothing);
      });
    });
  }
}
