import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/new_id.dart';
import '../../core/utils/result.dart';
import '../../domain/models/group.dart';
import '../../domain/models/product.dart';
import '../services/in_memory_list_service.dart';
import '../services/list_service.dart';
import '../services/service_providers.dart';

/// Moves the products of the list made without an account into the personal list of the
/// account the user signed in with. Only products move, matched by name without regard
/// to case; a product the account list already has is skipped. Plans, trips and marks
/// stay behind (they are dropped with the local copy). The local copy is deleted only
/// after the products were written, so a failure leaves it for the next try.
class LocalListMerger {
  LocalListMerger({required this.local, required this.cloud});

  final InMemoryListService local;
  final ListService cloud;
  bool _running = false;

  /// True when something was merged or the local list was empty of products.
  Future<Result<bool>> merge(String userId) async {
    if (_running) return const Ok(false);
    _running = true;
    try {
      final localId = personalGroupId(groupUserIds.first);
      final snapshot = local.snapshotOf(localId);
      if (snapshot.isEmpty) return const Ok(false);

      final targetId = personalGroupId(userId);
      final existing = await cloud.getProducts(targetId);
      if (existing case Failure(:final error)) return Failure(error);
      final known = {
        for (final p in (existing as Ok<List<Product>>).value)
          _key(p.name): p.position,
      };
      var next = known.values.fold<double>(0, (a, b) => a > b ? a : b);

      final mine = [...snapshot.products]..sort(byPosition);
      for (final p in mine) {
        if (known.containsKey(_key(p.name))) continue;
        next += 1;
        known[_key(p.name)] = next;
        final created = await cloud.createProduct(
          Product(
            id: newId(),
            groupId: targetId,
            name: p.name,
            position: next,
            planned: p.planned,
            plannedBy: p.planned ? userId : null,
            plannedAt: p.plannedAt,
          ),
        );
        if (created case Failure(:final error)) return Failure(error);
      }
      await local.deleteGroupData(localId);
      debugPrint('local list merged into the account');
      return const Ok(true);
    } finally {
      _running = false;
    }
  }

  static String _key(String name) => name.trim().toLowerCase();
}

/// Null in tests (no cloud list service); `main` sets the real one.
final localListMergerProvider = Provider<LocalListMerger?>((ref) {
  final cloud = ref.watch(realListServiceProvider);
  if (cloud == null) return null;
  return LocalListMerger(
    local: ref.watch(inMemoryListServiceProvider),
    cloud: cloud,
  );
});
