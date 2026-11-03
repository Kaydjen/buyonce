import 'dart:async';

import 'package:buyonce/core/utils/result.dart';
import 'package:buyonce/data/services/account_service.dart';
import 'package:buyonce/data/services/in_memory_list_service.dart';
import 'package:buyonce/data/services/service_providers.dart';
import 'package:buyonce/domain/models/account.dart';
import 'package:buyonce/domain/models/product.dart';
import 'package:buyonce/presentation/view_models/groups/groups_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Real implements AccountService {
  @override
  String? signedInUserId = 'uid-1';
  @override
  Stream<String?> get signedInUserIdChanges => const Stream.empty();
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
  test('signed in, the local list moves into the personal list', () async {
    final local = InMemoryListService(seed: false);
    await local.createProduct(
      const Product(id: 'a', groupId: 'personal-me', name: 'Milk', position: 1),
    );
    final cloud = InMemoryListService(seed: false);
    final container = ProviderContainer(
      overrides: [
        realAccountServiceProvider.overrideWithValue(_Real()),
        inMemoryListServiceProvider.overrideWithValue(local),
        realListServiceProvider.overrideWithValue(cloud),
      ],
    );
    addTearDown(container.dispose);
    container.listen(localMergeProvider, (_, _) {});
    await container.read(groupsViewModelProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(local.snapshotOf('personal-me').isEmpty, isTrue);
    final moved =
        (await cloud.getProducts('personal-uid-1') as Ok<List<Product>>).value;
    expect(moved.map((p) => p.name), ['Milk']);
  });

  test('signed out, the local list stays', () async {
    final local = InMemoryListService(seed: false);
    await local.createProduct(
      const Product(id: 'a', groupId: 'personal-me', name: 'Milk', position: 1),
    );
    final container = ProviderContainer(
      overrides: [
        inMemoryListServiceProvider.overrideWithValue(local),
        realListServiceProvider.overrideWithValue(
          InMemoryListService(seed: false),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(localMergeProvider, (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(local.snapshotOf('personal-me').products, hasLength(1));
  });
}
