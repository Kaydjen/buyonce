import 'package:buyonce/presentation/view_models/groups/groups_view_model.dart';
import 'package:buyonce/presentation/widgets/notice_banner.dart';
import 'package:buyonce/data/repositories/list_repository.dart';
import 'package:buyonce/data/services/in_memory_group_service.dart';
import 'package:buyonce/data/services/in_memory_list_service.dart';
import 'package:buyonce/data/services/service_providers.dart';
import 'package:buyonce/domain/models/group.dart';
import 'package:buyonce/main.dart';
import 'package:buyonce/presentation/widgets/product_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// [seed] false starts like a release build: no groups, the first-run screen.
Future<void> pumpApp(WidgetTester tester, {bool seed = true}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        inMemoryListServiceProvider.overrideWithValue(
          InMemoryListService(seed: seed),
        ),
        inMemoryGroupServiceProvider.overrideWithValue(
          InMemoryGroupService(seed: seed),
        ),
      ],
      child: const BuyOnceApp(),
    ),
  );
  await tester.pumpAndSettle();
}

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

/// The text field of the open dialog; the screen behind may have its own.
Finder rowNamed(String name) =>
    find.descendant(of: find.byType(ProductRow), matching: find.text(name));

final dialogField = find.descendant(
  of: find.byType(AlertDialog),
  matching: find.byType(TextField),
);

/// A button of the open dialog; the same words may sit on the screen behind it.
Future<void> tapDialog(WidgetTester tester, String text) async {
  await tester.tap(
    find.descendant(of: find.byType(AlertDialog), matching: find.text(text)),
  );
  await tester.pumpAndSettle();
}

Future<void> openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('groupButton')));
  await tester.pumpAndSettle();
}

Future<void> openSettings(WidgetTester tester) async {
  await openSheet(tester);
  await tapText(tester, 'Group settings');
}

String shownGroup(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(const Key('groupButton')),
        matching: find.byType(Text),
      ),
    )
    .data!;

Future<void> createGroup(WidgetTester tester, String name) async {
  await tester.enterText(dialogField, name);
  await tester.pumpAndSettle();
  await tapDialog(tester, 'Create');
}

void main() {
  testWidgets('a fresh install opens a working personal list', (tester) async {
    await pumpApp(tester, seed: false);
    expect(shownGroup(tester), 'Personal');
    expect(find.byKey(const Key('tabShop')), findsOneWidget);
    expect(find.byType(ProductRow), findsNothing);
    // Shop is the start screen; with no history it still has Frequent and its search.
    expect(find.text('Frequent'), findsOneWidget);
    expect(find.byKey(const Key('findButton')), findsOneWidget);
    expect(find.text('To buy'), findsNothing);

    // Add a product on Plan, mark it on Shop, close the trip.
    await tester.tap(find.byKey(const Key('tabPlan')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('addField')), 'Tea');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tabShop')));
    await tester.pumpAndSettle();
    await tapText(tester, 'Tea');
    expect(find.text('Done 1'), findsOneWidget);
    expect(find.text('Send 1'), findsNothing);
    await tester.tap(find.byKey(const Key('sendButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('presence')), findsNothing);
    expect(find.byType(NoticeBanner), findsNothing);
    final repo = containerOf(tester).read(listRepositoryProvider);
    final trips = ((await repo.getOpenTrips()) as dynamic).value as List;
    expect(trips, isEmpty);
  });

  testWidgets('the personal list has no invite code and no group settings', (
    tester,
  ) async {
    await pumpApp(tester, seed: false);
    await openSheet(tester);
    expect(find.text('New group'), findsOneWidget);
    expect(find.text('Join group'), findsOneWidget);
    expect(find.text('Group settings'), findsNothing);
  });

  testWidgets('personal list: a wrong code keeps the dialog and says so', (
    tester,
  ) async {
    await pumpApp(tester, seed: false);
    await openSheet(tester);
    await tapText(tester, 'Join group');
    await tester.enterText(dialogField, 'nope00');
    await tester.pumpAndSettle();
    await tapDialog(tester, 'Join');
    expect(find.text('No group with this code'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('personal list: a right code joins, any case, personal stays', (
    tester,
  ) async {
    await pumpApp(tester, seed: false);
    final container = containerOf(tester);
    await container
        .read(inMemoryGroupServiceProvider)
        .putGroup(
          const Group(
            id: 'g1',
            name: 'Cabin',
            utcOffset: Duration.zero,
            ownerId: 'partner',
            memberIds: ['partner'],
            inviteCode: 'ABC234',
          ),
        );
    await openSheet(tester);
    await tapText(tester, 'Join group');
    await tester.enterText(dialogField, 'abc234');
    await tester.pumpAndSettle();
    await tapDialog(tester, 'Join');
    expect(shownGroup(tester), 'Cabin');
    await openSheet(tester);
    expect(find.widgetWithText(ListTile, 'Personal'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Cabin'), findsOneWidget);
  });

  testWidgets('creating a group keeps the personal data and lists it first', (
    tester,
  ) async {
    await pumpApp(tester, seed: false);
    await tester.tap(find.byKey(const Key('tabPlan')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('addField')), 'Tea');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await openSheet(tester);
    await tapText(tester, 'New group');
    await createGroup(tester, 'Cabin');
    expect(shownGroup(tester), 'Cabin');
    await openSheet(tester);
    final titles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((t) => (t.title as Text).data)
        .toList();
    expect(titles.take(2), ['Personal', 'Cabin']);
    await tapText(tester, 'Personal');
    expect(shownGroup(tester), 'Personal');
    expect(rowNamed('Tea'), findsOneWidget);
  });

  testWidgets('switcher: New group and Join group are in the sheet', (
    tester,
  ) async {
    await pumpApp(tester);
    await openSheet(tester);
    await tapText(tester, 'New group');
    await createGroup(tester, 'Cabin');
    expect(shownGroup(tester), 'Cabin');
    await openSheet(tester);
    expect(find.widgetWithText(ListTile, 'Home'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Cabin'), findsOneWidget);
    await tapText(tester, 'Join group');
    expect(find.text('Join group'), findsOneWidget); // the dialog title
  });

  testWidgets('switcher: a dot marks a group with an unread notice', (
    tester,
  ) async {
    await pumpApp(tester);
    final repo = containerOf(tester).read(listRepositoryForProvider('mom'));
    await repo.toggleMark('mom-seed1', 'partner');
    await repo.sendTrip('partner');

    await openSheet(tester);
    expect(find.byKey(const Key('unreadDot')), findsOneWidget);
    // The dot sits on Mom's row, not on the shown group.
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Mom'),
        matching: find.byKey(const Key('unreadDot')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('settings: members, code, mute', (tester) async {
    await pumpApp(tester);
    await openSettings(tester);
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Anna'), findsOneWidget);
    expect(find.text('Owner · You'), findsOneWidget);
    expect(find.text('HOME01'), findsOneWidget);

    await tester.tap(find.byKey(const Key('muteGroup')));
    await tester.pumpAndSettle();
    final muted = containerOf(tester).read(inMemoryGroupServiceProvider);
    final groups = (await muted.getGroups()) as dynamic;
    expect(
      (groups.value as List<Group>)
          .firstWhere((g) => g.id == 'home')
          .mutedUserIds,
      {'me'},
    );
  });

  testWidgets('settings: rename', (tester) async {
    await pumpApp(tester);
    await openSettings(tester);
    await tester.tap(find.byKey(const Key('renameGroup')));
    await tester.pumpAndSettle();
    await tester.enterText(dialogField, 'Lodge');
    await tester.pumpAndSettle();
    await tapDialog(tester, 'Rename');
    expect(find.text('Lodge'), findsOneWidget); // the settings title
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(shownGroup(tester), 'Lodge');
  });

  testWidgets('settings: removing a member asks with outcome labels', (
    tester,
  ) async {
    await pumpApp(tester);
    await openSettings(tester);
    await tester.tap(find.byKey(const Key('remove-partner')));
    await tester.pumpAndSettle();
    expect(find.text('Remove Anna?'), findsOneWidget);
    await tapDialog(tester, 'Keep Anna');
    expect(find.text('Anna'), findsOneWidget);

    await tester.tap(find.byKey(const Key('remove-partner')));
    await tester.pumpAndSettle();
    await tapDialog(tester, 'Remove Anna');
    expect(find.text('Anna'), findsNothing);
    expect(find.byKey(const Key('remove-partner')), findsNothing);
  });

  testWidgets(
    'settings: leaving moves to another group, Stay changes nothing',
    (tester) async {
      await pumpApp(tester);
      await openSettings(tester);
      await tester.tap(find.byKey(const Key('leaveGroup')));
      await tester.pumpAndSettle();
      expect(find.text('Leave Home?'), findsOneWidget);
      await tapDialog(tester, 'Stay');
      expect(find.byKey(const Key('leaveGroup')), findsOneWidget);

      await tester.tap(find.byKey(const Key('leaveGroup')));
      await tester.pumpAndSettle();
      await tapDialog(tester, 'Leave group');
      expect(shownGroup(tester), 'Mom');
      await openSheet(tester);
      expect(find.widgetWithText(ListTile, 'Home'), findsNothing);
    },
  );

  testWidgets('settings: deleting asks and removes the group for good', (
    tester,
  ) async {
    await pumpApp(tester);
    await openSettings(tester);
    await tester.tap(find.byKey(const Key('deleteGroup')));
    await tester.pumpAndSettle();
    expect(find.text('Delete Home?'), findsOneWidget);
    await tapDialog(tester, 'Keep group');
    expect(find.byKey(const Key('deleteGroup')), findsOneWidget);

    await tester.tap(find.byKey(const Key('deleteGroup')));
    await tester.pumpAndSettle();
    await tapDialog(tester, 'Delete group');
    expect(shownGroup(tester), 'Mom');
    final lists = containerOf(tester).read(listRepositoryForProvider('home'));
    expect(((await lists.getProducts()) as dynamic).value, isEmpty);
  });

  testWidgets('leaving the last group returns to the personal list', (
    tester,
  ) async {
    await pumpApp(tester, seed: false);
    await openSheet(tester);
    await tapText(tester, 'New group');
    await createGroup(tester, 'Cabin');
    await openSettings(tester);
    await tester.tap(find.byKey(const Key('leaveGroup')));
    await tester.pumpAndSettle();
    await tapDialog(tester, 'Leave group');
    expect(shownGroup(tester), 'Personal');
  });

  testWidgets('a member who is not the owner cannot rename or delete', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.longPress(find.byKey(const Key('groupButton')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Anna'),
      ),
    );
    await tester.pumpAndSettle();
    await openSettings(tester);
    expect(find.byKey(const Key('leaveGroup')), findsOneWidget);
    expect(find.byKey(const Key('renameGroup')), findsNothing);
    expect(find.byKey(const Key('deleteGroup')), findsNothing);
    expect(find.byKey(const Key('remove-me')), findsNothing);
  });
}
