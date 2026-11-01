import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/result.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../domain/models/user_profile.dart';

/// Display names of all known users. Screens read one name through [userNameProvider].
class UserNamesViewModel extends AsyncNotifier<Map<String, String>> {
  @override
  Future<Map<String, String>> build() => _load();

  Future<Map<String, String>> _load() async =>
      switch (await ref.read(userRepositoryProvider).getNames()) {
        Ok(:final value) => value,
        Failure(:final error) => throw error,
      };

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
