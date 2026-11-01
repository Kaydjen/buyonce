import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/result.dart';
import '../../../data/repositories/group_repository.dart';
import '../../../data/repositories/list_repository.dart';
import '../../../domain/models/group.dart';
import '../account/account_view_model.dart';
import '../session/session.dart';

/// The groups of the signed-in user. Every action reloads the list and moves the
/// selection when it has to (a new group is shown at once, a left group is not).
class GroupsViewModel extends AsyncNotifier<List<Group>> {
  @override
  Future<List<Group>> build() => _load(
    ref.watch(groupRepositoryProvider),
    ref.watch(currentUserIdProvider),
    ref.watch(accountViewModelProvider.select((a) => a.value != null)),
  );

  /// Every user has a personal list, created here on first use. Without an account
  /// (local mode) only the personal list is shown: groups are online.
  Future<List<Group>> _load(
    GroupRepository repo,
    String userId,
    bool signedIn,
  ) async {
    final ensured = await repo.ensurePersonal(userId);
    if (ensured case Failure(:final error)) throw error;
    return switch (await repo.getGroupsOf(userId)) {
      Ok(:final value) =>
        signedIn ? value : value.where((g) => g.personal).toList(),
      Failure(:final error) => throw error,
    };
  }

  GroupRepository get _repo => ref.read(groupRepositoryProvider);
  String get _userId => ref.read(currentUserIdProvider);

  Future<Result<T>> _reload<T>(Result<T> result) async {
    if (result is Ok<T>) {
      state = AsyncData(
        await _load(
          _repo,
          _userId,
          ref.read(accountViewModelProvider).value != null,
        ),
      );
    }
    return result;
  }

  Future<Result<Group>> create(String name) async {
    final result = await _reload(await _repo.createGroup(name, _userId));
    if (result case Ok(:final value)) {
      ref.read(selectedGroupIdProvider.notifier).select(value.id);
    }
    return result;
  }

  Future<Result<Group>> join(String code) async {
    final result = await _reload(await _repo.joinByCode(code, _userId));
    if (result case Ok(:final value)) {
      ref.read(selectedGroupIdProvider.notifier).select(value.id);
    }
    return result;
  }

  Future<Result<void>> rename(String groupId, String name) async =>
      _reload(await _repo.rename(groupId, _userId, name));

  Future<Result<void>> removeMember(String groupId, String memberId) async =>
      _reload(await _repo.removeMember(groupId, _userId, memberId));

  Future<Result<void>> leave(String groupId) async =>
      _reload(await _repo.leave(groupId, _userId));

  Future<Result<void>> delete(String groupId) async =>
      _reload(await _repo.delete(groupId, _userId));

  Future<Result<void>> setMuted(String groupId, bool muted) async =>
      _reload(await _repo.setMuted(groupId, _userId, muted));

  /// Groups where this user has a notice they have not dismissed yet (the switcher
  /// marks them with a dot).
  Future<Set<String>> unreadGroupIds() async {
    final groups = state.value ?? const <Group>[];
    final unread = <String>{};
    for (final group in groups) {
      final notices = await ref
          .read(listRepositoryForProvider(group.id))
          .getNotices(_userId);
      if (notices case Ok(:final value) when value.isNotEmpty) {
        unread.add(group.id);
      }
    }
    return unread;
  }
}

final groupsViewModelProvider =
    AsyncNotifierProvider<GroupsViewModel, List<Group>>(GroupsViewModel.new);

/// The group shown now: the picked one while the user belongs to it, else the first
/// real group, else the personal list; null only while the groups load.
final activeGroupIdProvider = Provider<String?>((ref) {
  final groups = ref.watch(groupsViewModelProvider).value;
  if (groups == null || groups.isEmpty) return null;
  final picked = ref.watch(selectedGroupIdProvider);
  if (groups.any((g) => g.id == picked)) return picked;
  return (groups.where((g) => !g.personal).firstOrNull ?? groups.first).id;
});

/// The list repository of the group shown now.
final listRepositoryProvider = Provider((ref) {
  final groupId = ref.watch(activeGroupIdProvider);
  if (groupId == null) throw StateError('No active group');
  return ref.watch(listRepositoryForProvider(groupId));
});
