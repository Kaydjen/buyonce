import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/new_id.dart';
import '../../core/utils/result.dart';
import '../../core/utils/result_x.dart';
import '../../domain/models/group.dart';
import '../services/group_service.dart';
import '../services/list_service.dart';
import '../services/identity.dart';

/// Groups and their members: create, join by code, rename, remove a member, leave,
/// delete. Only the owner renames, removes members and deletes.
class GroupRepository {
  GroupRepository(this._groups, this._lists);
  final GroupService _groups;
  final ListService _lists;

  /// Groups [userId] belongs to, in the order they were created.
  /// The personal list comes first.
  Future<Result<List<Group>>> getGroupsOf(String userId) =>
      _groups.getGroups(userId).map(_personalFirst);

  /// The same as [getGroupsOf], live.
  Stream<Result<List<Group>>> watchGroupsOf(String userId) => _groups
      .watchGroups(userId)
      .map(
        (result) => switch (result) {
          Ok(:final value) => Ok(_personalFirst(value)),
          Failure(:final error) => Failure(error),
        },
      );

  List<Group> _personalFirst(List<Group> all) => [
    for (final g in all)
      if (g.personal) _current(g),
    for (final g in all)
      if (!g.personal) g,
  ];

  /// The personal list of [userId], created on first use (no invite code, one member).
  Future<Result<Group>> ensurePersonal(String userId) async {
    final existing = await getGroup(personalGroupId(userId));
    if (existing is Ok<Group>) return existing;
    return (await _groups.create(
      id: personalGroupId(userId),
      name: 'Personal',
      utcOffset: DateTime.now().timeZoneOffset,
      ownerId: userId,
      personal: true,
    )).map(_current);
  }

  /// The device's zone may change; a personal list follows it.
  Group _current(Group g) =>
      g.personal ? g.copyWith(utcOffset: DateTime.now().timeZoneOffset) : g;

  Future<Result<Group>> getGroup(String groupId) =>
      _groups.getGroup(groupId).map(_current);

  /// A new group owned by [userId]; its lists start empty.
  Future<Result<Group>> createGroup(
    String name,
    String userId, {
    Duration? utcOffset,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return const Failure(GroupError.emptyName);
    return _groups.create(
      id: newId(),
      name: trimmed,
      utcOffset: utcOffset ?? DateTime.now().timeZoneOffset,
      ownerId: userId,
    );
  }

  /// Joins the group with this code (case and spaces are ignored); joining a group the
  /// user is already in changes nothing.
  Future<Result<Group>> joinByCode(String code, String userId) =>
      _groups.join(code.trim().toUpperCase(), userId);

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
          : _groups.rename(groupId, trimmed),
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
        return _drop(
          group,
          userId,
          newOwnerId: group.ownerId == userId ? rest.first : null,
        );
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
      _groups.setMuted(groupId, userId, muted);

  Future<Result<void>> _asOwner(
    String groupId,
    String actorId,
    Future<Result<void>> Function(Group group) action,
  ) => getGroup(groupId).andThen(
    (group) async => group.ownerId == actorId
        ? action(group)
        : const Failure<void>(GroupError.notOwner),
  );

  Future<Result<void>> _drop(
    Group group,
    String userId, {
    String? newOwnerId,
  }) async {
    // The data first: once the member is gone the rules no longer let them touch it.
    final cleared = await _lists.deleteMemberData(group.id, userId);
    if (cleared case Failure(:final error)) return Failure(error);
    return _groups.removeMember(group.id, userId, newOwnerId: newOwnerId);
  }

  Future<Result<void>> _delete(String groupId) async {
    // The data first: once the group is gone nobody may read or delete it.
    final cleared = await _lists.deleteGroupData(groupId);
    if (cleared case Failure(:final error)) return Failure(error);
    return _groups.delete(groupId);
  }
}

final groupRepositoryProvider = Provider(
  (ref) => GroupRepository(
    ref.watch(groupServiceProvider),
    ref.watch(listServiceProvider),
  ),
);
