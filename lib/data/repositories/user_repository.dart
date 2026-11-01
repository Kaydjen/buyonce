import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/result.dart';
import '../../core/utils/result_x.dart';
import '../../domain/models/user_profile.dart';
import '../services/in_memory_user_service.dart';
import '../services/service_providers.dart';

/// Display names of users, by user id.
class UserRepository {
  UserRepository(this._service);
  final InMemoryUserService _service;

  Future<Result<Map<String, String>>> getNames() => _service.getProfiles().map(
    (profiles) => {for (final p in profiles) p.id: p.displayName},
  );

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
  (ref) => UserRepository(ref.watch(inMemoryUserServiceProvider)),
);
