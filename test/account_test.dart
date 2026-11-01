import 'package:buyonce/core/utils/result.dart';
import 'package:buyonce/data/repositories/group_repository.dart';
import 'package:buyonce/data/services/in_memory_account_service.dart';
import 'package:buyonce/data/services/in_memory_group_service.dart';
import 'package:buyonce/data/services/in_memory_list_service.dart';
import 'package:buyonce/data/services/in_memory_user_service.dart';
import 'package:buyonce/data/services/service_providers.dart';
import 'package:buyonce/domain/models/account.dart';
import 'package:buyonce/domain/models/group.dart';
import 'package:buyonce/domain/models/user_profile.dart';
import 'package:buyonce/main.dart';
import 'package:buyonce/presentation/view_models/account/account_view_model.dart';
import 'package:buyonce/presentation/view_models/groups/groups_view_model.dart';
import 'package:buyonce/presentation/view_models/list/list_view_model.dart';
import 'package:buyonce/presentation/view_models/users/user_names_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  bool seed = true,
  InMemoryAccountService? accounts,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        inMemoryListServiceProvider.overrideWithValue(
          InMemoryListService(seed: seed),
        ),
        inMemoryGroupServiceProvider.overrideWithValue(
          InMemoryGroupService(seed: seed),
        ),
        inMemoryUserServiceProvider.overrideWithValue(
          InMemoryUserService(seed: seed),
        ),
        inMemoryAccountServiceProvider.overrideWithValue(
          accounts ?? InMemoryAccountService(seed: seed),
        ),
      ],
      child: const BuyOnceApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('menuButton')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Settings'));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> tapDialog(WidgetTester tester, String text) async {
  await tester.tap(
    find.descendant(of: find.byType(AlertDialog), matching: find.text(text)),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('a Google first name is cut to 10 characters', () {
    expect(prefillDisplayName('Alexandra-Maria'), 'Alexandra-');
    expect(prefillDisplayName('Anna'), 'Anna');
    expect(prefillDisplayName('   '), isNull);
  });

  testWidgets('Account shows name, Google account, Sign out, Delete account', (
    tester,
  ) async {
    await pumpApp(tester);
    await openSettings(tester);
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('me@example.com'), findsOneWidget);
    expect(find.byKey(const Key('signOut')), findsOneWidget);
    expect(find.byKey(const Key('deleteAccount')), findsOneWidget);
  });

  testWidgets('the name is edited, 1-10 characters, and shows in groups', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    await openSettings(tester);
    await tapKey(tester, 'accountName');
    final field = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    // The field refuses an eleventh character.
    await tester.enterText(field, '12345678901');
    expect(tester.widget<TextField>(field).controller!.text.length, 10);
    await tester.enterText(field, '  ');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
          .onPressed,
      isNull,
    );
    await tester.enterText(field, ' Alexandra ');
    await tester.pumpAndSettle();
    await tapDialog(tester, 'Save');
    expect(find.text('Alexandra'), findsOneWidget);
    expect(container.read(userNameProvider('me')), 'Alexandra');
  });

  testWidgets('sign out leads to local mode with the personal list only; '
      'signing in again keeps the name and skips the name screen', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    await openSettings(tester);
    await tapKey(tester, 'signOut');
    // Back on the list, no login screen.
    expect(find.byKey(const Key('menuButton')), findsOneWidget);
    expect(find.byKey(const Key('signIn')), findsNothing);
    expect(find.text('Personal'), findsOneWidget);
    final groups = container.read(groupsViewModelProvider).requireValue;
    expect(groups.every((g) => g.personal), isTrue);

    await openSettings(tester);
    expect(find.byKey(const Key('signOut')), findsNothing);
    expect(find.byKey(const Key('deleteAccount')), findsNothing);
    await tapKey(tester, 'accountSignIn');
    expect(find.byKey(const Key('nameField')), findsNothing);
    expect(find.byKey(const Key('menuButton')), findsOneWidget);
    expect(container.read(userNameProvider('me')), 'Alex');
    expect(
      container.read(groupsViewModelProvider).requireValue.length,
      greaterThan(1),
    );
  });

  testWidgets('deleting leaves every group; an owner passes the group on', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    await openSettings(tester);
    await tapKey(tester, 'deleteAccount');
    expect(find.text('Leave your groups first'), findsNothing);
    await tapDialog(tester, 'Delete account');
    expect(container.read(accountViewModelProvider).value, isNull);
    final groups = container.read(groupRepositoryProvider);
    for (final id in ['home', 'mom', 'work']) {
      final g = (await groups.getGroup(id) as Ok<Group>).value;
      expect(g.memberIds, ['partner']);
      expect(g.ownerId, 'partner');
    }
    expect(container.read(userNameProvider('me')), unnamedUser);
  });

  testWidgets('a member who owns nothing deletes the account', (tester) async {
    final container = await pumpApp(tester);
    await container.read(listViewModelProvider.notifier).selectUser('partner');
    await tester.pumpAndSettle();
    await openSettings(tester);
    expect(find.text('Anna'), findsWidgets);
    await tapKey(tester, 'deleteAccount');
    await tapDialog(tester, 'Delete account');
    // Local mode: the account, the name and the memberships are gone.
    expect(find.byKey(const Key('menuButton')), findsOneWidget);
    expect(container.read(accountViewModelProvider).value, isNull);
    expect(container.read(userNameProvider('partner')), unnamedUser);
    final groups = await container
        .read(groupRepositoryProvider)
        .getGroupsOf('partner');
    expect(
      (groups as Ok<List<Group>>).value.map((g) => g.personal),
      everyElement(isTrue),
    );
    final home = await container.read(groupRepositoryProvider).getGroup('home');
    expect((home as Ok<Group>).value.memberIds, ['me']);
  });

  testWidgets('a failed re-authentication deletes nothing', (tester) async {
    final accounts = InMemoryAccountService(seed: true)..failReauth = true;
    final container = await pumpApp(tester, accounts: accounts);
    await container.read(listViewModelProvider.notifier).selectUser('partner');
    await tester.pumpAndSettle();
    await openSettings(tester);
    await tapKey(tester, 'deleteAccount');
    await tapDialog(tester, 'Delete account');
    expect(find.text("Couldn't confirm. Try again."), findsOneWidget);
    expect(container.read(accountViewModelProvider).value, isA<Account>());
    expect(container.read(userNameProvider('partner')), 'Anna');
  });
}
