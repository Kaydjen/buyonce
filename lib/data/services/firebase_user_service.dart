import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/utils/result.dart';
import '../../domain/models/user_profile.dart';
import 'user_service.dart';

/// Display names in `profiles/{uid}` (the rules allow `get` by any signed-in user and a
/// write only by the owner of the profile).
class FirebaseUserService implements UserService {
  FirebaseUserService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _profiles =>
      _db.collection('profiles');

  /// One `get` per user. A user whose read failed is left out (shown as "Member"); the
  /// whole read fails only when every single one did, so nothing is silently empty.
  @override
  Future<Result<Map<String, String>>> getNames(Set<String> userIds) async {
    final names = <String, String>{};
    Object? failure;
    var failed = 0;
    await Future.wait([
      for (final id in userIds)
        _profiles
            .doc(id)
            .get()
            .then((doc) {
              final name = doc.data()?['displayName'];
              if (name is String) names[id] = name;
            })
            .catchError((Object error) {
              failure = error;
              failed++;
            }),
    ]);
    if (userIds.isNotEmpty && failed == userIds.length) {
      return Failure(failure!);
    }
    return Ok(names);
  }

  /// Shown at once from the local cache; if the server refuses, the log says so.
  @override
  Future<Result<void>> putProfile(UserProfile profile) {
    _profiles
        .doc(profile.id)
        .set({'displayName': profile.displayName})
        .catchError(
          (Object error) => debugPrint('profile write refused: $error'),
        );
    return Future.value(const Ok(null));
  }

  @override
  Future<Result<void>> deleteProfile(String userId) async {
    try {
      await _profiles.doc(userId).delete().timeout(const Duration(seconds: 10));
      return const Ok(null);
    } catch (error) {
      return Failure(error);
    }
  }
}
