import 'dart:async';

import 'package:buyonce/core/utils/result.dart';
import 'package:buyonce/data/services/account_service.dart';
import 'package:buyonce/data/services/identity.dart';
import 'package:buyonce/data/services/in_memory_group_service.dart';
import 'package:buyonce/data/services/in_memory_user_service.dart';
import 'package:buyonce/data/services/service_providers.dart';
import 'package:buyonce/domain/models/account.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A real account service that is only a uid and a stream of its changes.
class _FakeReal implements AccountService {
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
  final fakeGroups = InMemoryGroupService(seed: false);
  final realGroups = InMemoryGroupService(seed: false);
  final fakeUsers = InMemoryUserService(seed: false);
  final realUsers = InMemoryUserService(seed: false);

  ProviderContainer make(_FakeReal account) {
    final container = ProviderContainer(
      overrides: [
        realAccountServiceProvider.overrideWithValue(account),
        inMemoryGroupServiceProvider.overrideWithValue(fakeGroups),
        realGroupServiceProvider.overrideWithValue(realGroups),
        inMemoryUserServiceProvider.overrideWithValue(fakeUsers),
        realUserServiceProvider.overrideWithValue(realUsers),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('signed out: the fake id and the in-memory services', () {
    final c = make(_FakeReal());
    c.listen(currentUserIdProvider, (_, _) {});
    expect(c.read(currentUserIdProvider), 'me');
    expect(c.read(groupServiceProvider), same(fakeGroups));
    expect(c.read(userServiceProvider), same(fakeUsers));
  });

  test('signed in for real: the uid and the Firestore services', () async {
    final account = _FakeReal()..signedInUserId = 'uid-1';
    final c = make(account);
    c.listen(currentUserIdProvider, (_, _) {});
    expect(c.read(currentUserIdProvider), 'uid-1');
    expect(c.read(groupServiceProvider), same(realGroups));
    expect(c.read(userServiceProvider), same(realUsers));
  });

  test('the identity follows a sign-in and a sign-out', () async {
    final account = _FakeReal();
    final c = make(account);
    c.listen(currentUserIdProvider, (_, _) {});
    account.changes.add('uid-2');
    await pumpEventQueue();
    expect(c.read(currentUserIdProvider), 'uid-2');
    expect(c.read(groupServiceProvider), same(realGroups));
    account.changes.add(null);
    await pumpEventQueue();
    expect(c.read(currentUserIdProvider), 'me');
    expect(c.read(groupServiceProvider), same(fakeGroups));
  });

  test('the debug partner stays fake even while the phone is signed in', () {
    final account = _FakeReal()..signedInUserId = 'uid-1';
    final c = make(account);
    c.listen(currentUserIdProvider, (_, _) {});
    c.read(userSlotProvider.notifier).select('partner');
    expect(c.read(currentUserIdProvider), 'partner');
    expect(c.read(groupServiceProvider), same(fakeGroups));
    expect(c.read(userServiceProvider), same(fakeUsers));
  });
}
