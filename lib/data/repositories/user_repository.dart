import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/result.dart';
import '../../domain/models/user_profile.dart';
import '../services/identity.dart';
import '../services/user_service.dart';

/// Display names of users, by user id.
class UserRepository {
  UserRepository(this._service);
  final UserService _service;

  /// Names of these users; a user without a name is missing from the map.
  Future<Result<Map<String, String>>> getNames(Set<String> userIds) =>
      _service.getNames(userIds);

  Future<Result<void>> deleteProfile(String userId) =>
      _service.deleteProfile(userId);

  /// Saves the name when it is 1-10 characters after trimming.
  Future<Result<void>> setDisplayName(String userId, String name) async {
    final clean = cleanDisplayName(name);
    if (clean == null) return const Failure(UserError.invalidName);
    return _service.putProfile(UserProfile(id: userId, displayName: clean));
  }
}

final userRepositoryProvider = Provider(
  (ref) => UserRepository(ref.watch(userServiceProvider)),
);
