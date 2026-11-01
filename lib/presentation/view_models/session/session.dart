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

/// Sessions of the users, in memory, to tell which products are "new" for a user: the
/// ones another member made needed after this user's previous session ended. A session
/// ends when the app was out of sight for a while or (debug) the fake user is switched.
/// A group's baseline is the end of the last session in which the user looked at it, so
/// a group not opened for several sessions still shows what was added meanwhile.
class VisitTracker {
  final _session = <String, int>{};
  final _viewed = <(String, String), int>{};
  final _lastSeen = <(String, String), DateTime>{};
  final _baseline = <(String, String), DateTime?>{};

  /// The user looks at the group. Returns the time the user's previous session of this
  /// group ended; null if there was none (nothing is new then). Repeated calls within
  /// one session return the same value.
  DateTime? enter(String groupId, String userId) {
    final key = (groupId, userId);
    final session = _session[userId] ?? 0;
    if (_viewed[key] != session) {
      _baseline[key] = _lastSeen[key];
      _viewed[key] = session;
    }
    return _baseline[key];
  }

  /// The user's current session ended at [at]; the next [enter] starts a new one.
  void end(String userId, DateTime at) {
    final session = _session[userId] ?? 0;
    for (final entry in _viewed.entries) {
      if (entry.key.$2 == userId && entry.value == session) {
        _lastSeen[entry.key] = at;
      }
    }
    _session[userId] = session + 1;
  }
}

final visitTrackerProvider = Provider<VisitTracker>((_) => VisitTracker());

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
