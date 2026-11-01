import 'package:flutter/foundation.dart';

import '../../core/utils/result.dart';
import '../../domain/models/user_profile.dart';

/// Fake storage of user profiles for the UX stage; the accounts backend replaces it.
class InMemoryUserService {
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

  Future<Result<List<UserProfile>>> getProfiles() async =>
      Ok(_profiles.values.toList());

  Future<Result<void>> deleteProfile(String userId) async {
    _profiles.remove(userId);
    return const Ok(null);
  }

  Future<Result<void>> putProfile(UserProfile profile) async {
    _profiles[profile.id] = profile;
    return const Ok(null);
  }
}
