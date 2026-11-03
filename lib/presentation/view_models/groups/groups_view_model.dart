import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/result.dart';
import '../../../data/repositories/group_repository.dart';
import '../../../data/repositories/list_repository.dart';
import '../../../domain/models/group.dart';
import '../account/account_view_model.dart';
import '../../../data/services/identity.dart';
import '../../../data/services/service_providers.dart';
import '../list/sync_state.dart';
import '../session/session.dart';

/// The groups of the signed-in user. Every action reloads the list and moves the
/// selection when it has to (a new group is shown at once, a left group is not).
class GroupsViewModel extends AsyncNotifier<List<Group>> {
  @override
  Future<List<Group>> build() async {
    final repo = ref.watch(groupRepositoryProvider);
    final userId = ref.watch(currentUserIdProvider);
    final signedIn = ref.watch(
      accountViewModelProvider.select((a) => a.value != null),
    );
    final first = await _load(repo, userId, signedIn);
    // From here the groups follow the server: a member who joins or leaves, a rename
    // on another phone.
    final subscriptions = [
      repo.watchGroupsOf(userId).skip(1).listen((result) {
        if (result case Ok(:final value)) {
          state = AsyncData(_visible(value, signedIn));
        }
      }),
      ref
          .read(groupServiceProvider)
          .writeErrors
          .listen((_) => ref.read(writeFailuresProvider.notifier).report()),
    ];
    ref.onDispose(() {
      for (final s in subscriptions) {
        s.cancel();
      }
    });
    return first;
  }

  static List<Group> _visible(List<Group> all, bool signedIn) =>
      signedIn ? all : all.where((g) => g.personal).toList();

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
      Ok(:final value) => _visible(value, signedIn),
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

/// A tap on a push shows its group (watched by the app root). An id the user does not
/// belong to is ignored by [activeGroupIdProvider].
final pushOpenProvider = Provider<void>((ref) {
  final push = ref.watch(realPushServiceProvider);
  if (push == null) return;
  final subscription = push.openedGroupIds.listen(
    (id) => ref.read(selectedGroupIdProvider.notifier).select(id),
    onError: (Object _) {},
  );
  ref.onDispose(subscription.cancel);
});

/// The list repository of the group shown now.
final listRepositoryProvider = Provider((ref) {
  final groupId = ref.watch(activeGroupIdProvider);
  if (groupId == null) throw StateError('No active group');
  return ref.watch(listRepositoryForProvider(groupId));
});
