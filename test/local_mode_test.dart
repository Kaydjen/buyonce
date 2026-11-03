import 'dart:async';

import 'package:buyonce/data/services/in_memory_account_service.dart';
import 'package:buyonce/data/services/in_memory_group_service.dart';
import 'package:buyonce/data/services/in_memory_list_service.dart';
import 'package:buyonce/data/services/in_memory_user_service.dart';
import 'package:buyonce/data/services/service_providers.dart';
import 'package:buyonce/data/services/settings_service.dart';
import 'package:buyonce/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account_test.dart' show pumpApp, tapKey;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('"Continue without account" is remembered after a restart', (
    tester,
  ) async {
    await pumpApp(tester, seed: false);
    expect(find.byKey(const Key('signIn')), findsOneWidget);
    await tapKey(tester, 'continueLocal');
    expect(find.byKey(const Key('menuButton')), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getBool('localMode'), true);

    // A new app start with the same stored values: no login screen.
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester, seed: false);
    expect(find.byKey(const Key('signIn')), findsNothing);
    expect(find.byKey(const Key('menuButton')), findsOneWidget);
  });

  testWidgets('a slow read of the stored choice shows a loader, not the login '
      'screen', (tester) async {
    final prefs = Completer<SharedPreferences>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsServiceProvider.overrideWithValue(
            SettingsService(prefs.future),
          ),
          inMemoryListServiceProvider.overrideWithValue(
            InMemoryListService(seed: false),
          ),
          inMemoryGroupServiceProvider.overrideWithValue(
            InMemoryGroupService(seed: false),
          ),
          inMemoryUserServiceProvider.overrideWithValue(
            InMemoryUserService(seed: false),
          ),
          inMemoryAccountServiceProvider.overrideWithValue(
            InMemoryAccountService(seed: false),
          ),
        ],
        child: const BuyOnceApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('signIn')), findsNothing);

    SharedPreferences.setMockInitialValues({});
    prefs.complete(SharedPreferences.getInstance());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('signIn')), findsOneWidget);
  });
}
