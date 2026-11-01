import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/new_id.dart';
import '../../core/utils/result.dart';
import '../../core/utils/result_x.dart';
import '../../domain/models/group.dart';
import '../services/in_memory_group_service.dart';
import '../services/in_memory_list_service.dart';
import '../services/service_providers.dart';

/// Groups and their members: create, join by code, rename, remove a member, leave,
/// delete. Only the owner renames, removes members and deletes.
class GroupRepository {
  GroupRepository(this._groups, this._lists);
  final InMemoryGroupService _groups;
  final InMemoryListService _lists;

  /// Groups [userId] belongs to, in the order they were created.
  /// The personal list comes first.
  Future<Result<List<Group>>> getGroupsOf(String userId) =>
      _groups.getGroups().map(
        (all) => [
          for (final g in all)
            if (g.memberIds.contains(userId) && g.personal) _current(g),
          for (final g in all)
            if (g.memberIds.contains(userId) && !g.personal) g,
        ],
      );

  /// The personal list of [userId], created on first use (no invite code, one member).
  Future<Result<Group>> ensurePersonal(String userId) async {
    final id = personalGroupId(userId);
    final existing = await getGroup(id);
    if (existing is Ok<Group>) return existing;
    final group = Group(
      id: id,
      name: 'Personal',
      utcOffset: DateTime.now().timeZoneOffset,
      ownerId: userId,
      memberIds: [userId],
      inviteCode: '',
      personal: true,
    );
    return (await _groups.putGroup(group)).map((_) => group);
  }

  /// The device's zone may change; a personal list follows it.
  Group _current(Group g) =>
      g.personal ? g.copyWith(utcOffset: DateTime.now().timeZoneOffset) : g;

  Future<Result<Group>> getGroup(String groupId) =>
      _groups.getGroups().andThen((all) async {
        final found = all.where((g) => g.id == groupId).firstOrNull;
        return found == null
            ? const Failure<Group>(GroupError.notFound)
            : Ok(_current(found));
      });

  /// A new group owned by [userId]; its lists start empty.
  Future<Result<Group>> createGroup(
    String name,
    String userId, {
    Duration? utcOffset,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return const Failure(GroupError.emptyName);
    final group = Group(
      id: newId(),
      name: trimmed,
      utcOffset: utcOffset ?? DateTime.now().timeZoneOffset,
      ownerId: userId,
      memberIds: [userId],
      inviteCode: await _freshCode(),
    );
    return (await _groups.putGroup(group)).map((_) => group);
  }

  /// Joins the group with this code (case and spaces are ignored); joining a group the
  /// user is already in changes nothing.
  Future<Result<Group>> joinByCode(String code, String userId) async {
    final wanted = code.trim().toUpperCase();
    return _groups.getGroups().andThen((all) async {
      final found = wanted.isEmpty
          ? null
          : all.where((g) => !g.personal && g.inviteCode == wanted).firstOrNull;
      if (found == null) return const Failure<Group>(GroupError.unknownCode);
      if (found.memberIds.contains(userId)) return Ok(found);
      final joined = found.copyWith(memberIds: [...found.memberIds, userId]);
      return (await _groups.putGroup(joined)).map((_) => joined);
    });
  }

  Future<Result<void>> rename(String groupId, String actorId, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return Future.value(const Failure(GroupError.emptyName));
    }
    return _asOwner(
      groupId,
      actorId,
      (group) async => group.personal
          ? const Failure<void>(GroupError.personalList)
          : _groups.putGroup(group.copyWith(name: trimmed)),
    );
  }

  Future<Result<void>> removeMember(
    String groupId,
    String actorId,
    String memberId,
  ) => _asOwner(groupId, actorId, (group) async {
    if (memberId == group.ownerId) return const Ok<void>(null);
    return _drop(group, memberId);
  });

  /// The user leaves. The owner leaving passes the group to the next member; the last
  /// member leaving deletes the group.
  Future<Result<void>> leave(String groupId, String userId) =>
      getGroup(groupId).andThen((group) async {
        if (group.personal) return const Failure<void>(GroupError.personalList);
        if (!group.memberIds.contains(userId)) return const Ok<void>(null);
        if (group.memberIds.length == 1) return _delete(groupId);
        final rest = [...group.memberIds]..remove(userId);
        final next = group.ownerId == userId ? rest.first : group.ownerId;
        return _drop(group.copyWith(ownerId: next), userId);
      });

  Future<Result<void>> delete(String groupId, String actorId) => _asOwner(
    groupId,
    actorId,
    (group) async => group.personal
        ? const Failure<void>(GroupError.personalList)
        : _delete(groupId),
  );

  /// Account deletion: the user's personal list goes with all its data.
  Future<Result<void>> deletePersonal(String userId) =>
      _delete(personalGroupId(userId));

  /// Mutes or unmutes the notifications of the group for [userId].
  Future<Result<void>> setMuted(String groupId, String userId, bool muted) =>
      getGroup(groupId).andThen(
        (group) => _groups.putGroup(
          group.copyWith(
            mutedUserIds: {
              for (final id in group.mutedUserIds)
                if (id != userId) id,
              if (muted) userId,
            },
          ),
        ),
      );

  Future<Result<void>> _asOwner(
    String groupId,
    String actorId,
    Future<Result<void>> Function(Group group) action,
  ) => getGroup(groupId).andThen(
    (group) async => group.ownerId == actorId
        ? action(group)
        : const Failure<void>(GroupError.notOwner),
  );

  Future<Result<void>> _drop(Group group, String userId) async {
    final saved = await _groups.putGroup(
      group.copyWith(
        memberIds: [
          for (final id in group.memberIds)
            if (id != userId) id,
        ],
        mutedUserIds: {
          for (final id in group.mutedUserIds)
            if (id != userId) id,
        },
      ),
    );
    if (saved case Failure(:final error)) return Failure(error);
    return _lists.deleteMemberData(group.id, userId);
  }

  Future<Result<void>> _delete(String groupId) async {
    final removed = await _groups.deleteGroup(groupId);
    if (removed case Failure(:final error)) return Failure(error);
    return _lists.deleteGroupData(groupId);
  }

  /// Six characters without the look-alikes 0, O, 1, I.
  Future<String> _freshCode() async {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    final taken = ((await _groups.getGroups()) as Ok<List<Group>>).value
        .map((g) => g.inviteCode)
        .toSet();
    while (true) {
      final code = String.fromCharCodes([
        for (var i = 0; i < 6; i++)
          alphabet.codeUnitAt(random.nextInt(alphabet.length)),
      ]);
      if (!taken.contains(code)) return code;
    }
  }
}

final groupRepositoryProvider = Provider(
  (ref) => GroupRepository(
    ref.watch(inMemoryGroupServiceProvider),
    ref.watch(inMemoryListServiceProvider),
  ),
);
