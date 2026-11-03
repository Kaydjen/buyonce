import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/result.dart';
import '../../domain/models/account.dart';
import '../../domain/models/group.dart';
import '../services/account_service.dart';
import '../services/in_memory_account_service.dart';
import '../services/push_service.dart';
import '../services/service_providers.dart';

class AccountRepository {
  AccountRepository(this._fake, [this._real, this._push]);
  final InMemoryAccountService _fake;

  /// The person holding the phone signs in for real; the other fake users stay fake
  /// (debug switch). Without a real service everyone is fake (tests).
  final AccountService? _real;

  /// The token of a real user is removed while the user can still do it.
  final PushService? _push;

  AccountService _of(String userId) =>
      userId == groupUserIds.first ? (_real ?? _fake) : _fake;

  Future<Result<Account?>> getAccount(String userId) =>
      _of(userId).getAccount(userId);

  set debugNextSignIn(DebugSignInOutcome outcome) => _fake.nextSignIn = outcome;

  DebugSignInOutcome get debugNextSignIn => _fake.nextSignIn;

  Future<Result<Account>> signIn(String userId) => _of(userId).signIn(userId);

  Future<Result<void>> signOut(String userId) async {
    await _dropToken(userId);
    return _of(userId).signOut(userId);
  }

  Future<void> _dropToken(String userId) async {
    final real = _real?.signedInUserId;
    if (userId == groupUserIds.first && real != null) {
      await _push?.unregister(real);
    }
  }

  Future<Result<void>> reauthenticate(String userId) =>
      _of(userId).reauthenticate(userId);

  Future<Result<void>> deleteAccount(String userId) async {
    await _dropToken(userId);
    return _of(userId).deleteAccount(userId);
  }
}

final accountRepositoryProvider = Provider(
  (ref) => AccountRepository(
    ref.watch(inMemoryAccountServiceProvider),
    ref.watch(realAccountServiceProvider),
    ref.watch(realPushServiceProvider),
  ),
);
