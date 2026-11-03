import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'account_service.dart';
import 'no_update_service.dart';
import 'group_service.dart';
import 'in_memory_account_service.dart';
import 'in_memory_group_service.dart';
import 'in_memory_list_service.dart';
import 'in_memory_update_service.dart';
import 'in_memory_user_service.dart';
import 'list_service.dart';
import 'push_service.dart';
import 'update_service.dart';
import 'user_service.dart';

final inMemoryListServiceProvider = Provider((ref) => InMemoryListService());

/// Products, trips, plans and notices on Firestore; null in tests, `main` sets it
/// (see `identity.dart`).
final realListServiceProvider = Provider<ListService?>((ref) => null);

final inMemoryGroupServiceProvider = Provider((ref) => InMemoryGroupService());

/// Groups on Firestore; null in tests, `main` sets it (see `identity.dart`).
final realGroupServiceProvider = Provider<GroupService?>((ref) => null);

final inMemoryUserServiceProvider = Provider((ref) => InMemoryUserService());

/// Names on Firestore; null in tests, `main` sets it (see `identity.dart`).
final realUserServiceProvider = Provider<UserService?>((ref) => null);

final inMemoryAccountServiceProvider = Provider(
  (ref) => InMemoryAccountService(),
);

/// The fake (a newer version always exists) only in debug builds; a release has no
/// update source yet.
final updateServiceProvider = Provider<UpdateService>(
  (ref) => kDebugMode ? InMemoryUpdateService() : NoUpdateService(),
);

/// The push token on Firestore; null in tests, `main` sets it (see `identity.dart`).
final realPushServiceProvider = Provider<PushService?>((ref) => null);

/// The real Google sign-in; null in tests, `main` sets the Firebase one.
final realAccountServiceProvider = Provider<AccountService?>((ref) => null);
