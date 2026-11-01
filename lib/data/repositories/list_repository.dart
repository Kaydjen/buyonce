import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/new_id.dart';
import '../../core/utils/result.dart';
import '../../core/utils/result_x.dart';
import '../../domain/models/group.dart';
import '../../domain/models/notice.dart';
import '../../domain/models/plan.dart';
import '../../domain/models/product.dart';
import '../../domain/models/purchase.dart';
import '../../domain/models/sort_key.dart';
import '../../domain/models/trip.dart';
import '../../domain/models/trip_mark.dart';
import '../services/in_memory_list_service.dart';
import '../services/service_providers.dart';
import 'group_repository.dart';

class ListRepository {
  ListRepository(this._service, this._groups, {this.groupId = defaultGroupId});
  final InMemoryListService _service;
  final GroupRepository _groups;
  final String groupId;

  Future<Result<List<Product>>> getProducts() => _service
      .getProducts(groupId)
      .map(
        (products) =>
            [...products]..sort((a, b) => a.position.compareTo(b.position)),
      );

  /// Open trips of the whole group: my marks and the partner's.
  Future<Result<List<Trip>>> getOpenTrips() => _service.getOpenTrips(groupId);

  /// How many sent trips contained each product.
  Future<Result<Map<String, int>>> getUsage() =>
      _service.getTrips(groupId).map((trips) {
        final count = <String, int>{};
        for (final trip in trips.where((t) => !t.isOpen)) {
          for (final m in trip.marks) {
            count[m.productId] = (count[m.productId] ?? 0) + 1;
          }
        }
        return count;
      });

  /// Every mark of every trip, sent or still open, newest first. A mark that was taken
  /// back is not in the trip any more, so it is not here.
  Future<Result<List<Purchase>>> getHistory() async {
    final products = await _service.getProducts(groupId);
    if (products case Failure(:final error)) return Failure(error);
    final names = {
      for (final p in (products as Ok<List<Product>>).value) p.id: p.name,
    };
    return _service.getTrips(groupId).map((trips) {
      final all = [
        for (final trip in trips)
          for (final m in trip.marks)
            if (names[m.productId] != null)
              Purchase(
                productName: names[m.productId]!,
                userId: m.userId,
                markedAt: m.markedAt,
              ),
      ]..sort((a, b) => b.markedAt.compareTo(a.markedAt));
      return all;
    });
  }

  /// A new product goes before the first or after the last one; positions may go negative.
  Future<Result<Product>> addProduct(
    String name, {
    required bool planned,
    bool atStart = false,
  }) => _service.getProducts(groupId).andThen((products) async {
    final position = atStart
        ? products.fold(0, (m, p) => p.position < m ? p.position : m) - 1
        : products.fold(-1, (m, p) => p.position > m ? p.position : m) + 1;
    final product = Product(
      id: newId(),
      groupId: groupId,
      name: name,
      position: position,
      planned: planned,
    );
    return (await _service.putProduct(product)).map((_) => product);
  });

  Future<Result<void>> setPlanned(Product product, bool planned) =>
      _service.putProduct(product.copyWith(planned: planned));

  /// Pinned plans (templates) first, then the newest.
  Future<Result<List<Plan>>> getPlans() => _service
      .getPlans(groupId)
      .map(
        (plans) => [...plans]
          ..sort((a, b) {
            if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
            return b.createdAt.compareTo(a.createdAt);
          }),
      );

  Future<Result<void>> applyPlan(Plan plan) =>
      _service.getProducts(groupId).andThen((products) async {
        final byId = {for (final p in products) p.id: p};
        for (final id in plan.productIds) {
          final p = byId[id];
          if (p == null || p.planned) continue;
          final saved = await _service.putProduct(p.copyWith(planned: true));
          if (saved case Failure(:final error)) return Failure(error);
        }
        return const Ok<void>(null);
      });

  Future<Result<void>> deletePlan(Plan plan) => _service.deletePlan(plan.id);

  /// Undo of [deletePlan]: the same plan comes back.
  Future<Result<void>> restorePlan(Plan plan) => _service.putPlan(plan);

  Future<Result<void>> setPinned(Plan plan, bool pinned) =>
      _service.putPlan(plan.copyWith(pinned: pinned));

  /// Saves the set of sent products as a plan; an identical set only refreshes its date.
  Future<Result<void>> _recordPlan(List<String> ids) async {
    if (ids.isEmpty) return const Ok<void>(null);
    return _service.getPlans(groupId).andThen((plans) {
      final key = ids.toSet();
      final same = plans
          .where(
            (p) =>
                p.productIds.length == key.length &&
                p.productIds.toSet().containsAll(key),
          )
          .firstOrNull;
      final now = DateTime.now();
      return _service.putPlan(
        same?.copyWith(createdAt: now) ??
            Plan(
              id: newId(),
              groupId: groupId,
              productIds: ids,
              createdAt: now,
            ),
      );
    });
  }

  /// Stores the given product order as manual positions.
  Future<Result<void>> reorder(List<String> orderedIds) =>
      _service.getProducts(groupId).andThen((products) async {
        final byId = {for (final p in products) p.id: p};
        for (var i = 0; i < orderedIds.length; i++) {
          final p = byId[orderedIds[i]];
          if (p == null || p.position == i) continue;
          final saved = await _service.putProduct(p.copyWith(position: i));
          if (saved case Failure(:final error)) return Failure(error);
        }
        return const Ok<void>(null);
      });

  /// One-time sort: reorders by [key]; the result is the new manual order.
  Future<Result<void>> sortBy(
    SortKey key,
  ) => _service.getProducts(groupId).andThen((products) {
    return _service.getTrips(groupId).andThen((trips) {
      final sent = trips.where((t) => !t.isOpen);
      final count = <String, int>{};
      final last = <String, DateTime>{};
      for (final trip in sent) {
        for (final m in trip.marks) {
          count[m.productId] = (count[m.productId] ?? 0) + 1;
          final seen = last[m.productId];
          if (seen == null || m.markedAt.isAfter(seen)) {
            last[m.productId] = m.markedAt;
          }
        }
      }
      final sorted = [...products]
        ..sort((a, b) => a.position.compareTo(b.position));
      final old = DateTime.fromMillisecondsSinceEpoch(0);
      // List.sort is not stable, so ties are broken by the previous position.
      int tie(Product a, Product b) => a.position.compareTo(b.position);
      sorted.sort(switch (key) {
        SortKey.alphabet => (a, b) {
          final c = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          return c != 0 ? c : tie(a, b);
        },
        SortKey.frequency => (a, b) {
          final c = (count[b.id] ?? 0).compareTo(count[a.id] ?? 0);
          return c != 0 ? c : tie(a, b);
        },
        SortKey.recent => (a, b) {
          final c = (last[b.id] ?? old).compareTo(last[a.id] ?? old);
          return c != 0 ? c : tie(a, b);
        },
      });
      return reorder([for (final p in sorted) p.id]);
    });
  });

  /// Notices this user has not dismissed yet, oldest first.
  Future<Result<List<Notice>>> getNotices(String userId) => _service
      .getNotices(groupId)
      .map(
        (all) =>
            all.where((n) => n.toUserId == userId && !n.seen).toList()
              ..sort((a, b) => a.sentAt.compareTo(b.sentAt)),
      );

  Future<Result<void>> markNoticesSeen(String userId) =>
      _service.getNotices(groupId).andThen((all) async {
        for (final n in all.where((n) => n.toUserId == userId && !n.seen)) {
          final saved = await _service.putNotice(n.copyWith(seen: true));
          if (saved case Failure(:final error)) return Failure(error);
        }
        return const Ok<void>(null);
      });

  /// Adds or removes the user's mark in the user's open trip; the first mark opens a trip.
  Future<Result<void>> toggleMark(String productId, String userId) =>
      _service.getOpenTrips(groupId).andThen((trips) {
        final open = trips.where((t) => t.userId == userId).firstOrNull;
        final now = DateTime.now();
        final trip =
            open ??
            Trip(id: newId(), groupId: groupId, userId: userId, startedAt: now);
        final marked = trip.marks.any((m) => m.productId == productId);
        final marks = marked
            ? trip.marks.where((m) => m.productId != productId).toList()
            : [
                ...trip.marks,
                TripMark(productId: productId, userId: userId, markedAt: now),
              ];
        return _service.putTrip(trip.copyWith(marks: marks));
      });

  /// Adds the user's marks for [productIds] (those already marked stay as they are)
  /// or removes them, in one write; the first mark opens a trip.
  Future<Result<void>> setMarks(
    List<String> productIds,
    String userId, {
    required bool marked,
  }) => _service.getOpenTrips(groupId).andThen((trips) {
    final open = trips.where((t) => t.userId == userId).firstOrNull;
    final now = DateTime.now();
    final trip =
        open ??
        Trip(id: newId(), groupId: groupId, userId: userId, startedAt: now);
    final ids = productIds.toSet();
    final kept = trip.marks.where((m) => !ids.contains(m.productId)).toList();
    final had = trip.marks.where((m) => ids.contains(m.productId)).toList();
    final marks = marked
        ? [
            ...trip.marks,
            for (final id in ids)
              if (!had.any((m) => m.productId == id))
                TripMark(productId: id, userId: userId, markedAt: now),
          ]
        : kept;
    return _service.putTrip(trip.copyWith(marks: marks));
  });

  /// Daily clearing of Bought: an open trip whose last mark is older than the start of
  /// today in the group's zone is sent first (the partner is notified), so its marks
  /// leave the list. A trip with a mark from today stays whole. History is kept.
  Future<Result<void>> sendStaleTrips({DateTime? now}) =>
      _groups.getGroup(groupId).andThen<void>((group) async {
        final trips = await _service.getOpenTrips(groupId);
        if (trips case Failure(:final error)) return Failure(error);
        final boundary = dayStart(now ?? DateTime.now(), group.utcOffset);
        for (final trip in (trips as Ok<List<Trip>>).value) {
          if (trip.marks.isEmpty) continue;
          if (trip.marks.any((m) => !m.markedAt.isBefore(boundary))) continue;
          final sent = await sendTrip(trip.userId);
          if (sent case Failure(:final error)) return Failure(error);
        }
        return const Ok<void>(null);
      });

  /// Closes the user's open trip; sent planned products leave the plan. Returns how many were sent.
  Future<Result<int>> sendTrip(String userId) =>
      _service.getOpenTrips(groupId).andThen<int>((trips) async {
        final open = trips.where((t) => t.userId == userId).firstOrNull;
        if (open == null || open.marks.isEmpty) return const Ok(0);
        final taken = {for (final m in open.marks) m.productId};
        final sent = await _service.putTrip(
          open.copyWith(sentAt: DateTime.now()),
        );
        if (sent case Failure(:final error)) return Failure(error);
        final products = await _service.getProducts(groupId);
        if (products case Failure(:final error)) return Failure(error);
        final all = (products as Ok<List<Product>>).value;
        // A group that is gone has nobody to tell.
        final members = switch (await _groups.getGroup(groupId)) {
          Ok(:final value) => value.memberIds,
          Failure() => const <String>[],
        };
        for (final other in members.where((u) => u != userId)) {
          final told = await _service.putNotice(
            Notice(
              id: newId(),
              groupId: groupId,
              toUserId: other,
              fromUserId: userId,
              productIds: taken.toList(),
              sentAt: DateTime.now(),
            ),
          );
          if (told case Failure(:final error)) return Failure(error);
        }
        final recorded = await _recordPlan([
          for (final p in [
            ...all,
          ]..sort((a, b) => a.position.compareTo(b.position)))
            if (taken.contains(p.id)) p.id,
        ]);
        if (recorded case Failure(:final error)) return Failure(error);
        for (final p in all) {
          if (!p.planned || !taken.contains(p.id)) continue;
          final saved = await _service.putProduct(p.copyWith(planned: false));
          if (saved case Failure(:final error)) return Failure(error);
        }
        return Ok(taken.length);
      });
}

/// A repository of one given group, also for a group that is not shown now.
final listRepositoryForProvider = Provider.family<ListRepository, String>(
  (ref, groupId) => ListRepository(
    ref.watch(inMemoryListServiceProvider),
    ref.watch(groupRepositoryProvider),
    groupId: groupId,
  ),
);
