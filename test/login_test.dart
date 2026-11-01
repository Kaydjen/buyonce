import 'package:buyonce/domain/models/account.dart';
import 'package:buyonce/presentation/view_models/account/account_view_model.dart';
import 'package:buyonce/presentation/view_models/users/user_names_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_test.dart' show openSettings, pumpApp, tapKey;

Future<void> pickOutcome(WidgetTester tester, DebugSignInOutcome o) async {
  await tester.longPress(find.byKey(const Key('signIn')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('outcome-${o.name}')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('first launch shows only the login screen', (tester) async {
    await pumpApp(tester, seed: false);
    expect(find.byKey(const Key('signIn')), findsOneWidget);
    expect(find.byKey(const Key('menuButton')), findsNothing);
  });

  testWidgets('progress replaces the button while signing in', (tester) async {
    await pumpApp(tester, seed: false);
    await tester.tap(find.byKey(const Key('signIn')));
    await tester.pump();
    expect(find.byKey(const Key('signInProgress')), findsOneWidget);
    expect(find.byKey(const Key('signIn')), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('signInProgress')), findsNothing);
  });

  testWidgets('first sign-in opens the name screen prefilled; Continue '
      'saves the name and opens the list', (tester) async {
    final container = await pumpApp(tester, seed: false);
    await tapKey(tester, 'signIn');
    expect(find.byKey(const Key('nameField')), findsOneWidget);
    final field = tester.widget<TextField>(find.byKey(const Key('nameField')));
    expect(field.controller!.text, 'Alexander');
    expect(find.byKey(const Key('menuButton')), findsNothing);

    await tester.enterText(find.byKey(const Key('nameField')), '  ');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('nameContinue')))
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byKey(const Key('nameField')), 'Sasha');
    await tester.pumpAndSettle();
    await tapKey(tester, 'nameContinue');
    expect(container.read(userNameProvider('me')), 'Sasha');
    expect(find.byKey(const Key('nameField')), findsNothing);
    expect(find.byKey(const Key('menuButton')), findsOneWidget);
    expect(container.read(namePendingProvider), isFalse);
  });

  testWidgets('a cancelled sign-in returns to the login screen silently', (
    tester,
  ) async {
    await pumpApp(tester, seed: false);
    await pickOutcome(tester, DebugSignInOutcome.cancel);
    await tapKey(tester, 'signIn');
    expect(find.byKey(const Key('signIn')), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a failed sign-in shows a snackbar; Retry signs in', (
    tester,
  ) async {
    await pumpApp(tester, seed: false);
    await pickOutcome(tester, DebugSignInOutcome.error);
    await tapKey(tester, 'signIn');
    expect(find.text("Couldn't sign in"), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    // The outcome falls back to success after one use.
    expect(find.byKey(const Key('nameField')), findsOneWidget);
  });

  testWidgets('Continue without account opens the personal list only', (
    tester,
  ) async {
    final container = await pumpApp(tester, seed: false);
    await tapKey(tester, 'continueLocal');
    expect(find.byKey(const Key('signIn')), findsNothing);
    expect(find.byKey(const Key('menuButton')), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);
    expect(container.read(accountViewModelProvider).value, isNull);
  });

  testWidgets('without an account New group and Join group ask to sign in', (
    tester,
  ) async {
    await pumpApp(tester, seed: false);
    await tapKey(tester, 'continueLocal');
    for (final item in ['New group', 'Join group']) {
      await tapKey(tester, 'groupButton');
      await tester.tap(find.text(item));
      await tester.pumpAndSettle();
      expect(find.text('Sign in to use groups'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in to use groups'), findsNothing);
      expect(find.byKey(const Key('menuButton')), findsOneWidget);
    }
  });

  testWidgets('Sign in from the dialog opens the name screen for a new user', (
    tester,
  ) async {
    await pumpApp(tester, seed: false);
    await tapKey(tester, 'continueLocal');
    await tapKey(tester, 'groupButton');
    await tester.tap(find.text('New group'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('signInRequiredYes')));
    // No animation runs while the fake sign-in waits, so settle alone would not wait.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nameField')), findsOneWidget);
  });

  testWidgets('debug: Settings can show the login screen again', (
    tester,
  ) async {
    await pumpApp(tester);
    await openSettings(tester);
    await tapKey(tester, 'debugShowLogin');
    expect(find.byKey(const Key('signIn')), findsOneWidget);
    expect(find.byKey(const Key('continueLocal')), findsOneWidget);
  });
}
