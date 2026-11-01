import 'package:flutter/foundation.dart';

import '../../core/utils/result.dart';
import '../../domain/models/group.dart';

/// Fake storage of groups for the UX stage; replaced by a backend service later.
class InMemoryGroupService {
  /// Debug builds start with three groups, so the lists can be tried at once; release
  /// builds start empty and show the first-run screen. Work lives in another zone so
  /// the day boundary can be checked per group.
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
      inviteCode: 'HOME01',
    ),
    Group(
      id: 'mom',
      name: 'Mom',
      utcOffset: Duration(hours: 3),
      ownerId: 'me',
      memberIds: ['me', 'partner'],
      inviteCode: 'MOM001',
    ),
    Group(
      id: 'work',
      name: 'Work',
      utcOffset: Duration(hours: 7),
      ownerId: 'me',
      memberIds: ['me', 'partner'],
      inviteCode: 'WORK01',
    ),
  ];

  final Map<String, Group> _groups = {};

  Future<Result<List<Group>>> getGroups() async => Ok(_groups.values.toList());

  Future<Result<void>> putGroup(Group group) async {
    _groups[group.id] = group;
    return const Ok(null);
  }

  Future<Result<void>> deleteGroup(String groupId) async {
    _groups.remove(groupId);
    return const Ok(null);
  }
}
