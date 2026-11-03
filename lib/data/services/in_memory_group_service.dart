import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/utils/invite_code.dart';
import '../../core/utils/result.dart';
import '../../domain/models/group.dart';
import 'group_service.dart';

/// Fake storage of groups for the fake users and tests.
class InMemoryGroupService implements GroupService {
  /// Debug builds start with three groups, so the lists can be tried at once; release
  /// builds start empty. Work lives in another zone so the day boundary can be checked
  /// per group.
  InMemoryGroupService({bool? seed}) {
    if (seed ?? kDebugMode) {
      for (final group in _seed) {
        _groups[group.id] = group;
      }
    }
  }

  static const _seed = [
    Group(
      id: defaultGroupId,
      name: 'Home',
      utcOffset: Duration(hours: 3),
      ownerId: 'me',
      memberIds: ['me', 'partner'],
      inviteCode: 'HOME0001',
    ),
    Group(
      id: 'mom',
      name: 'Mom',
      utcOffset: Duration(hours: 3),
      ownerId: 'me',
      memberIds: ['me', 'partner'],
      inviteCode: 'MOM00001',
    ),
    Group(
      id: 'work',
      name: 'Work',
      utcOffset: Duration(hours: 7),
      ownerId: 'me',
      memberIds: ['me', 'partner'],
      inviteCode: 'WORK0001',
    ),
  ];

  /// Insertion order is creation order.
  final Map<String, Group> _groups = {};
  final _changes = StreamController<void>.broadcast(sync: true);

  List<Group> _of(String userId) => [
    for (final g in _groups.values)
      if (g.memberIds.contains(userId)) g,
  ];

  void _save(Group group) {
    _groups[group.id] = group;
    _changes.add(null);
  }

  @override
  Stream<Object> get writeErrors => const Stream.empty();

  /// Test helper: stores a group as it is.
  Future<Result<void>> putGroup(Group group) async {
    _save(group);
    return const Ok(null);
  }

  @override
  Stream<Result<List<Group>>> watchGroups(String userId) {
    late final StreamController<Result<List<Group>>> controller;
    StreamSubscription<void>? subscription;
    controller = StreamController(
      onListen: () {
        controller.add(Ok(_of(userId)));
        subscription = _changes.stream.listen(
          (_) => controller.add(Ok(_of(userId))),
        );
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<Result<List<Group>>> getGroups(String userId) async => Ok(_of(userId));

  @override
  Future<Result<Group>> getGroup(String groupId) async {
    final group = _groups[groupId];
    return group == null ? const Failure(GroupError.notFound) : Ok(group);
  }

  @override
  Future<Result<Group>> create({
    required String id,
    required String name,
    required Duration utcOffset,
    required String ownerId,
    bool personal = false,
  }) async {
    final taken = {for (final g in _groups.values) g.inviteCode};
    var code = '';
    if (!personal) {
      do {
        code = newInviteCode();
      } while (taken.contains(code));
    }
    final group = Group(
      id: id,
      name: name,
      utcOffset: utcOffset,
      ownerId: ownerId,
      memberIds: [ownerId],
      inviteCode: code,
      personal: personal,
    );
    _save(group);
    return Ok(group);
  }

  @override
  Future<Result<Group>> join(String code, String userId) async {
    final found = code.isEmpty
        ? null
        : _groups.values
              .where((g) => !g.personal && g.inviteCode == code)
              .firstOrNull;
    if (found == null) return const Failure(GroupError.unknownCode);
    if (found.memberIds.contains(userId)) return Ok(found);
    if (found.memberIds.length >= maxGroupMembers) {
      return const Failure(GroupError.full);
    }
    final joined = found.copyWith(memberIds: [...found.memberIds, userId]);
    _save(joined);
    return Ok(joined);
  }

  @override
  Future<Result<void>> rename(String groupId, String name) =>
      _update(groupId, (g) => g.copyWith(name: name));

  @override
  Future<Result<void>> removeMember(
    String groupId,
    String userId, {
    String? newOwnerId,
  }) => _update(
    groupId,
    (g) => g.copyWith(
      ownerId: newOwnerId,
      memberIds: [
        for (final id in g.memberIds)
          if (id != userId) id,
      ],
      mutedUserIds: {
        for (final id in g.mutedUserIds)
          if (id != userId) id,
      },
    ),
  );

  @override
  Future<Result<void>> setMuted(String groupId, String userId, bool muted) =>
      _update(
        groupId,
        (g) => g.copyWith(
          mutedUserIds: {
            for (final id in g.mutedUserIds)
              if (id != userId) id,
            if (muted) userId,
          },
        ),
      );

  @override
  Future<Result<void>> delete(String groupId) async {
    if (_groups.remove(groupId) != null) _changes.add(null);
    return const Ok(null);
  }

  Future<Result<void>> _update(
    String groupId,
    Group Function(Group group) change,
  ) async {
    final group = _groups[groupId];
    if (group == null) return const Failure(GroupError.notFound);
    _save(change(group));
    return const Ok(null);
  }
}
