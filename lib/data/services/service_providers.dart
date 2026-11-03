import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'account_service.dart';
import 'in_memory_account_service.dart';
import 'in_memory_group_service.dart';
import 'in_memory_list_service.dart';
import 'in_memory_update_service.dart';
import 'in_memory_user_service.dart';
import 'update_service.dart';

final inMemoryListServiceProvider = Provider((ref) => InMemoryListService());

final inMemoryGroupServiceProvider = Provider((ref) => InMemoryGroupService());

final inMemoryUserServiceProvider = Provider((ref) => InMemoryUserService());

final inMemoryAccountServiceProvider = Provider(
  (ref) => InMemoryAccountService(),
);

final updateServiceProvider = Provider<UpdateService>(
  (ref) => InMemoryUpdateService(),
);

/// The real Google sign-in; null in tests, `main` sets the Firebase one.
final realAccountServiceProvider = Provider<AccountService?>((ref) => null);
