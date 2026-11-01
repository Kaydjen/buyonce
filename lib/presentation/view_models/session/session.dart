import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/group.dart';

/// Fake signed-in user for the UX stage; the debug menu switches it.
class CurrentUserId extends Notifier<String> {
  @override
  String build() => groupUserIds.first;

  void select(String userId) => state = userId;
}

final currentUserIdProvider = NotifierProvider<CurrentUserId, String>(
  CurrentUserId.new,
);

/// The group the user picked; null until the first pick. `activeGroupIdProvider` turns
/// it into a group the user actually belongs to.
class SelectedGroupId extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? groupId) => state = groupId;
}

final selectedGroupIdProvider = NotifierProvider<SelectedGroupId, String?>(
  SelectedGroupId.new,
);
