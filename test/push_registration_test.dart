import 'dart:async';

import 'package:buyonce/core/utils/result.dart';
import 'package:buyonce/data/repositories/account_repository.dart';
import 'package:buyonce/data/services/account_service.dart';
import 'package:buyonce/data/services/identity.dart';
import 'package:buyonce/data/services/in_memory_account_service.dart';
import 'package:buyonce/data/services/push_service.dart';
import 'package:buyonce/data/services/service_providers.dart';
import 'package:buyonce/domain/models/account.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Push implements PushService {
  final calls = <String>[];
  @override
  Future<void> register(String userId) async => calls.add('register $userId');
  @override
  Future<void> unregister(String userId) async =>
      calls.add('unregister $userId');
}

class _Real implements AccountService {
  final changes = StreamController<String?>.broadcast();
  @override
  String? signedInUserId;
  @override
  Stream<String?> get signedInUserIdChanges => changes.stream;
  @override
  Future<Result<Account?>> getAccount(String userId) async => const Ok(null);
  @override
  Future<Result<Account>> signIn(String userId) async =>
      const Failure(AccountError.signInFailed);
  @override
  Future<Result<void>> signOut(String userId) async => const Ok(null);
  @override
  Future<Result<void>> reauthenticate(String userId) async => const Ok(null);
  @override
  Future<Result<void>> deleteAccount(String userId) async => const Ok(null);
}

void main() {
  test('the token is registered for the signed-in user only', () async {
    final push = _Push();
    final real = _Real()..signedInUserId = 'uid-1';
    final container = ProviderContainer(
      overrides: [
        realAccountServiceProvider.overrideWithValue(real),
        realPushServiceProvider.overrideWithValue(push),
      ],
    );
    addTearDown(container.dispose);

    container.listen(pushRegistrationProvider, (_, _) {});
    expect(push.calls, ['register uid-1']);

    real.signedInUserId = null;
    real.changes.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(push.calls, ['register uid-1']); // nobody signed in: nothing to save
  });

  test('without a push service nothing happens', () {
    final container = ProviderContainer(
      overrides: [
        realAccountServiceProvider.overrideWithValue(
          _Real()..signedInUserId = 'uid-1',
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(pushRegistrationProvider, (_, _) {});
  });

  test('sign-out and account deletion remove the token first', () async {
    final push = _Push();
    final real = _Real()..signedInUserId = 'uid-1';
    final repository = AccountRepository(
      InMemoryAccountService(seed: false),
      real,
      push,
    );

    await repository.signOut('me');
    await repository.deleteAccount('me');
    await repository.signOut('partner'); // a fake user has no token

    expect(push.calls, ['unregister uid-1', 'unregister uid-1']);
  });
}
