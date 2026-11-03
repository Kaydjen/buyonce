import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/result.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../domain/models/group.dart';
import '../../../domain/models/user_profile.dart';
import '../account/account_view_model.dart';
import '../groups/groups_view_model.dart';
import '../session/session.dart';

/// Display names of all known users. Screens read one name through [userNameProvider].
class UserNamesViewModel extends AsyncNotifier<Map<String, String>> {
  @override
  Future<Map<String, String>> build() {
    // The names of the user and of everyone in the user's groups; read again when the
    // members change.
    ref.watch(groupsViewModelProvider.select(_memberKey));
    // A sign-in, a sign-out or another fake user changes whose names are read.
    ref.watch(accountViewModelProvider.select((a) => a.value?.userId));
    ref.watch(currentUserIdProvider);
    return _load();
  }

  static String _memberKey(AsyncValue<List<Group>> groups) => ([
    for (final g in groups.value ?? const <Group>[]) ...g.memberIds,
  ]..sort()).join(',');

  Future<Map<String, String>> _load() async {
    final ids = {
      ref.read(currentUserIdProvider),
      for (final g
          in ref.read(groupsViewModelProvider).value ?? const <Group>[])
        ...g.memberIds,
    };
    return switch (await ref.read(userRepositoryProvider).getNames(ids)) {
      Ok(:final value) => value,
      Failure(:final error) => throw error,
    };
  }

  /// Every place that shows the name updates once the names are reloaded.
  Future<Result<void>> setName(String userId, String name) async {
    final result = await ref
        .read(userRepositoryProvider)
        .setDisplayName(userId, name);
    if (result is Ok<void>) state = AsyncData(await _load());
    return result;
  }
}

final userNamesProvider =
    AsyncNotifierProvider<UserNamesViewModel, Map<String, String>>(
      UserNamesViewModel.new,
    );

/// The name shown for [userId]; [unnamedUser] until the profile has one.
final userNameProvider = Provider.family<String, String>(
  (ref, userId) => ref.watch(userNamesProvider).value?[userId] ?? unnamedUser,
);
