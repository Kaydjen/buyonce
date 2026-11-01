import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/result.dart';
import '../../domain/models/account.dart';
import '../services/in_memory_account_service.dart';
import '../services/service_providers.dart';

class AccountRepository {
  AccountRepository(this._service);
  final InMemoryAccountService _service;

  Future<Result<Account?>> getAccount(String userId) =>
      _service.getAccount(userId);

  set debugNextSignIn(DebugSignInOutcome outcome) =>
      _service.nextSignIn = outcome;

  DebugSignInOutcome get debugNextSignIn => _service.nextSignIn;

  Future<Result<Account>> signIn(String userId) => _service.signIn(userId);

  Future<Result<void>> signOut(String userId) => _service.signOut(userId);

  Future<Result<void>> reauthenticate(String userId) =>
      _service.reauthenticate(userId);

  Future<Result<void>> deleteAccount(String userId) =>
      _service.deleteAccount(userId);
}

final accountRepositoryProvider = Provider(
  (ref) => AccountRepository(ref.watch(inMemoryAccountServiceProvider)),
);
