import 'package:buyonce/core/utils/result.dart';
import 'package:buyonce/data/repositories/user_repository.dart';
import 'package:buyonce/data/services/in_memory_user_service.dart';
import 'package:buyonce/domain/models/user_profile.dart';
import 'package:buyonce/main.dart';
import 'package:buyonce/presentation/view_models/list/list_view_model.dart';
import 'package:buyonce/presentation/view_models/users/user_names_view_model.dart';
import 'package:flutter/material.dart';
import 'package:buyonce/presentation/view_models/groups/groups_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('names are 1-10 characters after trimming', () {
    expect(cleanDisplayName('  Mom '), 'Mom');
    expect(cleanDisplayName('Мама'), 'Мама');
    expect(cleanDisplayName('1234567890'), '1234567890');
    expect(cleanDisplayName('12345678901'), isNull);
    expect(cleanDisplayName('   '), isNull);
  });

  test('seeded debug users have distinct names, others fall back', () async {
    final seeded = UserRepository(InMemoryUserService(seed: true));
    final names = (await seeded.getNames({
      'me',
      'partner',
    }) as Ok<Map<String, String>>).value;
    expect(names['me'], isNot(names['partner']));

    final container = ProviderContainer(
      overrides: [
        userRepositoryProvider.overrideWithValue(
          UserRepository(InMemoryUserService(seed: false)),
        ),
      ],
    );
    addTearDown(container.dispose);
    // A listener, like the screens: without one a provider that restarts while loading
    // (its groups arrive) never completes the first future.
    container.listen(userNamesProvider, (_, _) {});
    await container.read(userNamesProvider.future);
    expect(container.read(userNameProvider('me')), unnamedUser);
  });

  test('names of the group members are read, not only the own one', () async {
    final container = ProviderContainer(
      overrides: [
        userRepositoryProvider.overrideWithValue(
          UserRepository(InMemoryUserService(seed: true)),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(userNamesProvider, (_, _) {});
    await container.read(groupsViewModelProvider.future);
    await container.read(userNamesProvider.future);
    await pumpEventQueue();
    expect(container.read(userNameProvider('partner')), 'Anna');
  });

  test('an invalid name is refused and changes nothing', () async {
    final repo = UserRepository(InMemoryUserService(seed: true));
    final result = await repo.setDisplayName('me', 'much too long name');
    expect((result as Failure).error, UserError.invalidName);
    final names =
        (await repo.getNames({'me'}) as Ok<Map<String, String>>).value;
    expect(names['me'], 'Alex');
  });

  testWidgets('changing a name updates the places that show it', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BuyOnceApp()));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    await container.read(listViewModelProvider.notifier).selectUser('partner');
    await tester.pumpAndSettle();
    // The debug strip shows the acting user's name.
    expect(find.text('Anna'), findsOneWidget);
    await container
        .read(userNamesProvider.notifier)
        .setName('partner', ' Mom ');
    await tester.pumpAndSettle();
    expect(find.text('Mom'), findsOneWidget);
    expect(find.text('Anna'), findsNothing);
  });
}
