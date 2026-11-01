import 'package:buyonce/core/utils/result.dart';
import 'package:buyonce/data/repositories/group_repository.dart';
import 'package:buyonce/data/repositories/list_repository.dart';
import 'package:buyonce/data/services/in_memory_group_service.dart';
import 'package:buyonce/data/services/in_memory_list_service.dart';
import 'package:buyonce/domain/models/group.dart';
import 'package:buyonce/domain/models/notice.dart';
import 'package:buyonce/domain/models/product.dart';
import 'package:buyonce/domain/models/trip.dart';
import 'package:flutter_test/flutter_test.dart';

typedef Env = ({
  GroupRepository groups,
  ListRepository Function(String groupId) lists,
});

/// Services without seeds: every test builds the groups it needs.
Env env() {
  final lists = InMemoryListService(seed: false);
  final groups = GroupRepository(InMemoryGroupService(seed: false), lists);
  return (
    groups: groups,
    lists: (id) => ListRepository(lists, groups, groupId: id),
  );
}

T ok<T>(Result<T> result) => (result as Ok<T>).value;

Object fail(Result<Object?> result) => (result as Failure).error;

void main() {
  test(
    'seeded groups exist in debug builds and list both fake users',
    () async {
      final groups = GroupRepository(
        InMemoryGroupService(),
        InMemoryListService(),
      );
      final mine = ok(await groups.getGroupsOf('me'));
      expect(mine.map((g) => g.name), ['Home', 'Mom', 'Work']);
      expect(mine.first.memberIds, ['me', 'partner']);
    },
  );

  test('create: owner is the only member, lists start empty', () async {
    final e = env();
    final group = ok(await e.groups.createGroup('  Cabin ', 'me'));
    expect(group.name, 'Cabin');
    expect(group.ownerId, 'me');
    expect(group.memberIds, ['me']);
    expect(group.inviteCode, hasLength(6));
    expect(ok(await e.lists(group.id).getProducts()), isEmpty);
    expect(ok(await e.groups.getGroupsOf('partner')), isEmpty);
  });

  test('create with an empty name fails', () async {
    final e = env();
    expect(fail(await e.groups.createGroup('  ', 'me')), GroupError.emptyName);
  });

  test('join by code ignores case and spaces, no duplicate member', () async {
    final e = env();
    final group = ok(await e.groups.createGroup('Cabin', 'me'));
    final code = group.inviteCode.toLowerCase();
    final joined = ok(await e.groups.joinByCode(' $code ', 'partner'));
    expect(joined.memberIds, ['me', 'partner']);
    expect(
      ok(await e.groups.joinByCode(group.inviteCode, 'partner')).memberIds,
      ['me', 'partner'],
    );
    expect(ok(await e.groups.getGroupsOf('partner')).single.id, group.id);
  });

  test('join with an unknown code fails', () async {
    final e = env();
    expect(
      fail(await e.groups.joinByCode('NOPE00', 'me')),
      GroupError.unknownCode,
    );
  });

  test('the group has no member limit', () async {
    final e = env();
    final group = ok(await e.groups.createGroup('Big', 'u0'));
    for (var i = 1; i < 12; i++) {
      await e.groups.joinByCode(group.inviteCode, 'u$i');
    }
    expect(ok(await e.groups.getGroup(group.id)).memberIds, hasLength(12));
  });

  test('only the owner renames, removes members and deletes', () async {
    final e = env();
    final group = ok(await e.groups.createGroup('Cabin', 'me'));
    await e.groups.joinByCode(group.inviteCode, 'partner');

    expect(
      fail(await e.groups.rename(group.id, 'partner', 'X')),
      GroupError.notOwner,
    );
    expect(
      fail(await e.groups.removeMember(group.id, 'partner', 'me')),
      GroupError.notOwner,
    );
    expect(
      fail(await e.groups.delete(group.id, 'partner')),
      GroupError.notOwner,
    );

    await e.groups.rename(group.id, 'me', 'Lodge');
    expect(ok(await e.groups.getGroup(group.id)).name, 'Lodge');
    expect(
      fail(await e.groups.rename(group.id, 'me', ' ')),
      GroupError.emptyName,
    );
  });

  test('removing a member drops their open trip, never the owner', () async {
    final e = env();
    final group = ok(await e.groups.createGroup('Cabin', 'me'));
    await e.groups.joinByCode(group.inviteCode, 'partner');
    final lists = e.lists(group.id);
    final nuts = ok(await lists.addProduct('Nuts', planned: true));
    await lists.toggleMark(nuts.id, 'partner');

    await e.groups.removeMember(group.id, 'me', 'me');
    expect(ok(await e.groups.getGroup(group.id)).memberIds, ['me', 'partner']);

    await e.groups.removeMember(group.id, 'me', 'partner');
    expect(ok(await e.groups.getGroup(group.id)).memberIds, ['me']);
    expect(ok(await lists.getOpenTrips()), isEmpty);
    expect(ok(await e.groups.getGroupsOf('partner')), isEmpty);
  });

  test(
    'leave: the owner passes the group on, the last member deletes it',
    () async {
      final e = env();
      final group = ok(await e.groups.createGroup('Cabin', 'me'));
      await e.groups.joinByCode(group.inviteCode, 'partner');
      await e.lists(group.id).addProduct('Nuts', planned: true);

      await e.groups.leave(group.id, 'me');
      final left = ok(await e.groups.getGroup(group.id));
      expect(left.memberIds, ['partner']);
      expect(left.ownerId, 'partner');
      expect(ok(await e.groups.getGroupsOf('me')), isEmpty);
      expect(ok(await e.lists(group.id).getProducts()), hasLength(1));

      await e.groups.leave(group.id, 'partner');
      expect(fail(await e.groups.getGroup(group.id)), GroupError.notFound);
      expect(ok(await e.lists(group.id).getProducts()), isEmpty);
    },
  );

  test(
    'delete removes the group with its products, plans and notices',
    () async {
      final e = env();
      final group = ok(await e.groups.createGroup('Cabin', 'me'));
      await e.groups.joinByCode(group.inviteCode, 'partner');
      final lists = e.lists(group.id);
      final nuts = ok(await lists.addProduct('Nuts', planned: true));
      await lists.toggleMark(nuts.id, 'me');
      await lists.sendTrip('me');

      await e.groups.delete(group.id, 'me');
      expect(fail(await e.groups.getGroup(group.id)), GroupError.notFound);
      expect(ok(await lists.getProducts()), isEmpty);
      expect(ok(await lists.getPlans()), isEmpty);
      expect(ok(await lists.getNotices('partner')), isEmpty);
    },
  );

  test('mute is kept per member', () async {
    final e = env();
    final group = ok(await e.groups.createGroup('Cabin', 'me'));
    await e.groups.joinByCode(group.inviteCode, 'partner');
    await e.groups.setMuted(group.id, 'partner', true);
    expect(ok(await e.groups.getGroup(group.id)).mutedUserIds, {'partner'});
    await e.groups.setMuted(group.id, 'partner', false);
    expect(ok(await e.groups.getGroup(group.id)).mutedUserIds, isEmpty);
  });

  test('Notify tells every other member of the group', () async {
    final e = env();
    final group = ok(await e.groups.createGroup('Cabin', 'me'));
    await e.groups.joinByCode(group.inviteCode, 'partner');
    await e.groups.joinByCode(group.inviteCode, 'dad');
    final lists = e.lists(group.id);
    final nuts = ok(await lists.addProduct('Nuts', planned: true));
    await lists.toggleMark(nuts.id, 'me');
    await lists.sendTrip('me');

    List<Notice> notices(Result<List<Notice>> r) => ok(r);
    expect(notices(await lists.getNotices('partner')), hasLength(1));
    expect(notices(await lists.getNotices('dad')), hasLength(1));
    expect(notices(await lists.getNotices('me')), isEmpty);
  });

  test('the day boundary comes from the zone of the stored group', () async {
    final e = env();
    final group = ok(
      await e.groups.createGroup(
        'Far',
        'me',
        utcOffset: const Duration(hours: 12),
      ),
    );
    final lists = e.lists(group.id);
    final nuts = ok(await lists.addProduct('Nuts', planned: true));
    await lists.toggleMark(nuts.id, 'me');
    await lists.sendStaleTrips(
      now: DateTime.now().add(const Duration(days: 2)),
    );
    expect(ok<List<Trip>>(await lists.getOpenTrips()), isEmpty);
    expect(
      ok<List<Product>>(await lists.getProducts()).single.planned,
      isFalse,
    );
  });

  group('personal list', () {
    test(
      'is created once per user, first in the list, in the device zone',
      () async {
        final e = env();
        final first = ok(await e.groups.ensurePersonal('me'));
        final again = ok(await e.groups.ensurePersonal('me'));
        expect(again.id, first.id);
        expect(first.personal, isTrue);
        expect(first.memberIds, ['me']);
        expect(first.inviteCode, isEmpty);
        final real = ok(await e.groups.createGroup('Cabin', 'me'));
        expect(ok(await e.groups.getGroupsOf('me')).map((g) => g.id), [
          first.id,
          real.id,
        ]);
        expect(first.utcOffset, DateTime.now().timeZoneOffset);
      },
    );

    test('cannot be left, renamed or deleted, and cannot be joined', () async {
      final e = env();
      final mine = ok(await e.groups.ensurePersonal('me'));
      expect(
        fail(await e.groups.leave(mine.id, 'me')),
        GroupError.personalList,
      );
      expect(
        fail(await e.groups.rename(mine.id, 'me', 'Other')),
        GroupError.personalList,
      );
      expect(
        fail(await e.groups.delete(mine.id, 'me')),
        GroupError.personalList,
      );
      expect(
        fail(await e.groups.joinByCode('', 'partner')),
        GroupError.unknownCode,
      );
      expect(ok(await e.groups.getGroupsOf('me')), hasLength(1));
    });

    test('closing a trip tells nobody', () async {
      final e = env();
      final mine = ok(await e.groups.ensurePersonal('me'));
      final lists = e.lists(mine.id);
      final product = ok(await lists.addProduct('Tea', planned: true));
      await lists.toggleMark(product.id, 'me');
      expect(ok(await lists.sendTrip('me')), 1);
      expect(ok(await lists.getNotices('me')), isEmpty);
      expect(ok(await lists.getOpenTrips()), isEmpty);
    });
  });
}
