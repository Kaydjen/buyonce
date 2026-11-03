import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/result.dart';
import '../../domain/models/account.dart';
import '../../domain/models/group.dart';
import '../services/account_service.dart';
import '../services/in_memory_account_service.dart';
import '../services/service_providers.dart';

class AccountRepository {
  AccountRepository(this._fake, [this._real]);
  final InMemoryAccountService _fake;

  /// The person holding the phone signs in for real; the other fake users stay fake
  /// (debug switch). Without a real service everyone is fake (tests).
  final AccountService? _real;

  AccountService _of(String userId) =>
      userId == groupUserIds.first ? (_real ?? _fake) : _fake;

  Future<Result<Account?>> getAccount(String userId) =>
      _of(userId).getAccount(userId);

  set debugNextSignIn(DebugSignInOutcome outcome) => _fake.nextSignIn = outcome;

  DebugSignInOutcome get debugNextSignIn => _fake.nextSignIn;

  Future<Result<Account>> signIn(String userId) => _of(userId).signIn(userId);

  Future<Result<void>> signOut(String userId) => _of(userId).signOut(userId);

  Future<Result<void>> reauthenticate(String userId) =>
      _of(userId).reauthenticate(userId);

  Future<Result<void>> deleteAccount(String userId) =>
      _of(userId).deleteAccount(userId);
}

final accountRepositoryProvider = Provider(
  (ref) => AccountRepository(
    ref.watch(inMemoryAccountServiceProvider),
    ref.watch(realAccountServiceProvider),
  ),
);
