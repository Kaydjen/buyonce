import 'package:flutter/foundation.dart';

import '../../core/utils/result.dart';
import '../../domain/models/user_profile.dart';
import 'user_service.dart';

/// Fake storage of user profiles for the fake users and tests.
class InMemoryUserService implements UserService {
  /// Debug builds start with named fake users; otherwise nobody has a name yet.
  InMemoryUserService({bool? seed}) {
    if (seed ?? kDebugMode) {
      for (final profile in _seed) {
        _profiles[profile.id] = profile;
      }
    }
  }

  static const _seed = [
    UserProfile(id: 'me', displayName: 'Alex'),
    UserProfile(id: 'partner', displayName: 'Anna'),
  ];

  final Map<String, UserProfile> _profiles = {};

  @override
  Future<Result<Map<String, String>>> getNames(Set<String> userIds) async =>
      Ok({
        for (final p in _profiles.values)
          if (userIds.contains(p.id)) p.id: p.displayName,
      });

  @override
  Future<Result<void>> deleteProfile(String userId) async {
    _profiles.remove(userId);
    return const Ok(null);
  }

  @override
  Future<Result<void>> putProfile(UserProfile profile) async {
    _profiles[profile.id] = profile;
    return const Ok(null);
  }
}
