import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/clip.dart';
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
import '../services/identity.dart';
import '../services/list_service.dart';
import 'group_repository.dart';

class ListRepository {
  ListRepository(this._service, this._groups, {this.groupId = defaultGroupId});
  final ListService _service;
  final GroupRepository _groups;
  final String groupId;

  Future<Result<List<Product>>> getProducts() =>
      _service.getProducts(groupId).map(_inCatalogOrder);

  static List<Product> _inCatalogOrder(List<Product> products) =>
      [...products]..sort(byPosition);

  static List<Plan> _templatesFirst(List<Plan> plans) =>
      [...plans]..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });

  static List<Notice> Function(List<Notice>) _unseenFor(String userId) =>
      (all) =>
          all.where((n) => n.toUserId == userId && !n.seen).toList()
            ..sort((a, b) => a.sentAt.compareTo(b.sentAt));

  /// Live data of the group (see [ListService]): the current value first, then every
  /// change, my own writes included, before the server has answered.
  Stream<Result<List<Product>>> watchProducts() =>
      _service.watchProducts(groupId).map((r) => r.map(_inCatalogOrder));

  Stream<Result<List<Trip>>> watchOpenTrips() =>
      _service.watchOpenTrips(groupId);

  Stream<Result<List<Plan>>> watchPlans() =>
      _service.watchPlans(groupId).map((r) => r.map(_templatesFirst));

  Stream<Result<List<Notice>>> watchNotices(String userId) =>
      _service.watchNotices(groupId).map((r) => r.map(_unseenFor(userId)));

  /// Writes (of any group) that were shown and then refused.
  Stream<ListWriteError> get writeErrors => _service.writeErrors;

  /// False while the app cannot reach the server.
  Stream<bool> get online => _service.online;

  /// Open trips of the whole group: my marks and the partner's.
  Future<Result<List<Trip>>> getOpenTrips() => _service.getOpenTrips(groupId);

  /// How many sent trips contained each product.
  Future<Result<Map<String, int>>> getUsage() => _service
      .getProducts(groupId)
      .map((products) => {for (final p in products) p.id: p.usage});

  /// Every mark of every trip, sent or still open, newest first. A mark that was taken
  /// back is not in the trip any more, so it is not here.
  Future<Result<List<Purchase>>> getHistory() async {
    final products = await _service.getProducts(groupId);
    if (products case Failure(:final error)) return Failure(error);
    final names = {
      for (final p in (products as Ok<List<Product>>).value) p.id: p.name,
    };
    return _service.getTrips(groupId, limit: historyTripLimit).map((trips) {
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
  /// [userId] is who plans the product; it matters when [planned] is true.
  Future<Result<Product>> addProduct(
    String name, {
    required bool planned,
    bool atStart = false,
    String? userId,
  }) => _service.getProducts(groupId).andThen((products) async {
    final position = atStart
        ? products.fold(0.0, (m, p) => p.position < m ? p.position : m) - 1
        : products.fold(-1.0, (m, p) => p.position > m ? p.position : m) + 1;
    final product = Product(
      id: newId(),
      groupId: groupId,
      name: clip(name, maxProductNameLength),
      position: position,
      planned: planned,
      plannedBy: planned ? userId : null,
      plannedAt: planned ? DateTime.now() : null,
    );
    return (await _service.createProduct(product)).map((_) => product);
  });

  /// Makes [names] needed, the first name on top. A catalog name just becomes needed, a
  /// name that is already needed changes nothing, an unknown one is created; names are
  /// compared without case. Returns how many products changed.
  Future<Result<int>> addProducts(List<String> names, String userId) async {
    final first = <String, String>{};
    for (final raw in names) {
      final name = raw.trim();
      if (name.isNotEmpty) first.putIfAbsent(name.toLowerCase(), () => name);
    }
    final products = await _service.getProducts(groupId);
    if (products case Failure(:final error)) return Failure(error);
    final byName = {
      for (final p in (products as Ok<List<Product>>).value)
        p.name.toLowerCase(): p,
    };
    var changed = 0;
    // Each new product goes before all others, so the last name is added first.
    for (final entry in first.entries.toList().reversed) {
      final existing = byName[entry.key];
      final Result<void> saved;
      if (existing == null) {
        saved = await addProduct(
          entry.value,
          planned: true,
          atStart: true,
          userId: userId,
        );
      } else if (existing.planned) {
        continue;
      } else {
        saved = await setPlanned(existing, true, userId);
      }
      if (saved case Failure(:final error)) return Failure(error);
      changed++;
    }
    return Ok(changed);
  }

  /// Planning records [userId] and the time; un-planning clears them.
  Future<Result<void>> setPlanned(
    Product product,
    bool planned,
    String userId,
  ) => _service.updateProduct(
    product.copyWith(
      planned: planned,
      plannedBy: userId,
      plannedAt: DateTime.now(),
    ),
  );

  /// Pinned plans (templates) first, then the newest.
  Future<Result<List<Plan>>> getPlans() =>
      _service.getPlans(groupId).map(_templatesFirst);

  /// Makes the plan's products needed, in one write.
  Future<Result<void>> applyPlan(Plan plan, String userId) =>
      _service.getProducts(groupId).andThen((products) {
        final byId = {for (final p in products) p.id: p};
        final now = DateTime.now();
        return _service.updateProducts([
          for (final id in plan.productIds)
            if (byId[id] case final p? when !p.planned)
              p.copyWith(planned: true, plannedBy: userId, plannedAt: now),
        ]);
      });

  Future<Result<void>> deletePlan(Plan plan) => _service.deletePlan(plan);

  /// Undo of [deletePlan]: the same plan comes back.
  Future<Result<void>> restorePlan(Plan plan) => _service.createPlan(plan);

  Future<Result<void>> setPinned(Plan plan, bool pinned) =>
      _service.updatePlan(plan.copyWith(pinned: pinned));

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
      return same == null
          ? _service.createPlan(
              Plan(
                id: newId(),
                groupId: groupId,
                productIds: ids,
                createdAt: now,
              ),
            )
          : _service.updatePlan(same.copyWith(createdAt: now));
    });
  }

  /// Stores the given product order as manual positions 0, 1, 2... (one write per
  /// product that changes). Used by the one-off sort and when a gap has run out.
  Future<Result<void>> reorder(List<String> orderedIds) =>
      _service.getProducts(groupId).andThen((products) {
        final byId = {for (final p in products) p.id: p};
        return _service.updateProducts([
          for (var i = 0; i < orderedIds.length; i++)
            if (byId[orderedIds[i]] case final p? when p.position != i)
              p.copyWith(position: i.toDouble()),
        ]);
      });

  /// Moves one product between its new neighbours: [above] is the product that will be
  /// right above it, [below] the one right below (null at the ends). One write: the
  /// position becomes the middle of the neighbours. When the neighbours are not apart
  /// ([minGap]), the whole list is numbered again once.
  Future<Result<void>> moveProduct(
    String productId, {
    String? above,
    String? below,
  }) => _service.getProducts(groupId).andThen((products) {
    final sorted = [...products]..sort(byPosition);
    final byId = {for (final p in sorted) p.id: p};
    final moved = byId[productId];
    if (moved == null) return Future.value(const Ok<void>(null));
    final top = above == null ? null : byId[above]?.position;
    final bottom = below == null ? null : byId[below]?.position;
    final double position;
    if (top != null && bottom != null) {
      if (bottom - top < minGap) {
        final ids = [for (final p in sorted) p.id]..remove(productId);
        ids.insert(ids.indexOf(above!) + 1, productId);
        return reorder(ids);
      }
      position = (top + bottom) / 2;
    } else if (top != null) {
      position = top + 1;
    } else if (bottom != null) {
      position = bottom - 1;
    } else {
      return Future.value(const Ok<void>(null));
    }
    return _service.updateProduct(moved.copyWith(position: position));
  });

  /// One-time sort: reorders by [key]; the result is the new manual order.
  Future<Result<void>> sortBy(
    SortKey key,
  ) => _service.getProducts(groupId).andThen((products) {
    return _service.getTrips(groupId, limit: recentTripLimit).andThen((trips) {
      // `usage` counts every sent trip; "recent" looks only at the latest ones.
      final sent = trips.where((t) => !t.isOpen).toList()
        ..sort((a, b) => b.sentAt!.compareTo(a.sentAt!));
      final last = <String, DateTime>{};
      for (final trip in sent.take(recentTripLimit)) {
        for (final m in trip.marks) {
          final seen = last[m.productId];
          if (seen == null || m.markedAt.isAfter(seen)) {
            last[m.productId] = m.markedAt;
          }
        }
      }
      final sorted = [...products]..sort(byPosition);
      final old = DateTime.fromMillisecondsSinceEpoch(0);
      // List.sort is not stable, so ties are broken by the previous position.
      int tie(Product a, Product b) => byPosition(a, b);
      sorted.sort(switch (key) {
        SortKey.alphabet => (a, b) {
          final c = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          return c != 0 ? c : tie(a, b);
        },
        SortKey.frequency => (a, b) {
          final c = b.usage.compareTo(a.usage);
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
  Future<Result<List<Notice>>> getNotices(String userId) =>
      _service.getNotices(groupId).map(_unseenFor(userId));

  /// Marks the user's notices as seen; with [sentBefore] only the ones sent before it.
  Future<Result<void>> markNoticesSeen(String userId, {DateTime? sentBefore}) =>
      _service.getNotices(groupId).andThen((all) async {
        for (final n in all.where(
          (n) =>
              n.toUserId == userId &&
              !n.seen &&
              (sentBefore == null || n.sentAt.isBefore(sentBefore)),
        )) {
          final saved = await _service.markNoticeSeen(n);
          if (saved case Failure(:final error)) return Failure(error);
        }
        return const Ok<void>(null);
      });

  /// When [userId] last asked for products in this group; null if never.
  Future<Result<DateTime?>> getAskedAt(String userId) =>
      _service.getAskedAt(groupId, userId);

  /// "Ask": tells every other member that [userId] needs [productIds], in one notice
  /// each, and remembers the time so these products are not asked for again. Returns
  /// how many products were announced; with nobody to tell, nothing is recorded.
  Future<Result<int>> ask(String userId, List<String> productIds) async {
    if (productIds.isEmpty) return const Ok(0);
    final members = switch (await _groups.getGroup(groupId)) {
      Ok(:final value) => value.memberIds,
      Failure() => const <String>[],
    };
    final others = members.where((u) => u != userId).toList();
    if (others.isEmpty) return const Ok(0);
    final saved = await _service.ask(
      groupId,
      userId,
      productIds,
      notify: others,
    );
    if (saved case Failure(:final error)) return Failure(error);
    return Ok(productIds.length);
  }

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
        return _saveTrip(open, trip.copyWith(marks: marks));
      });

  /// Adds the user's marks for [productIds] (those already marked stay as they are)
  /// or removes them, in one write; the first mark opens a trip.
  Future<Result<void>> setMarks(
    List<String> productIds,
    String userId, {
    required bool marked,
  }) => _service.getOpenTrips(groupId).andThen((trips) {
    final open = trips.where((t) => t.userId == userId).firstOrNull;
    // An Undo that comes after the trip was sent has nothing to take back.
    if (!marked && open == null) return Future.value(const Ok<void>(null));
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
    return _saveTrip(open, trip.copyWith(marks: marks));
  });

  /// Tells the server when to send the user's open trip if the phone cannot (null:
  /// never). No open trip, nothing to do.
  Future<Result<void>> setAutoSendAt(String userId, DateTime? at) =>
      _service.getOpenTrips(groupId).andThen((trips) {
        final open = trips.where((t) => t.userId == userId).firstOrNull;
        return open == null
            ? Future.value(const Ok<void>(null))
            : _service.setAutoSendAt(open, at);
      });

  /// The first mark creates the trip, later ones replace its marks.
  Future<Result<void>> _saveTrip(Trip? open, Trip trip) =>
      open == null ? _service.createTrip(trip) : _service.updateTripMarks(trip);

  /// Daily clearing of Bought: an open trip whose last mark is older than the start of
  /// today in the group's zone is sent first (the partner is notified), so its marks
  /// leave the list. A trip with a mark from today stays whole. History is kept.
  /// With [onlyUser] only that user's trip is sent: on the server nobody writes the trip
  /// of another member, the partner's stale trip is sent by their own phone (and by the
  /// server's clock).
  Future<Result<void>> sendStaleTrips({DateTime? now, String? onlyUser}) =>
      _groups.getGroup(groupId).andThen<void>((group) async {
        final trips = await _service.getOpenTrips(groupId);
        if (trips case Failure(:final error)) return Failure(error);
        final boundary = dayStart(now ?? DateTime.now(), group.utcOffset);
        for (final trip in (trips as Ok<List<Trip>>).value) {
          if (trip.marks.isEmpty) continue;
          if (onlyUser != null && trip.userId != onlyUser) continue;
          if (trip.marks.any((m) => !m.markedAt.isBefore(boundary))) continue;
          final sent = await sendTrip(trip.userId);
          if (sent case Failure(:final error)) return Failure(error);
        }
        return const Ok<void>(null);
      });

  /// Closes the user's open trip; sent planned products leave the plan. Returns how
  /// many were sent. The service closes the trip and, as the server's part, counts the
  /// usage and tells the other members; the plan is saved here.
  Future<Result<int>> sendTrip(String userId) =>
      _service.getOpenTrips(groupId).andThen<int>((trips) async {
        final open = trips.where((t) => t.userId == userId).firstOrNull;
        if (open == null || open.marks.isEmpty) return const Ok(0);
        final taken = {for (final m in open.marks) m.productId};
        final products = await _service.getProducts(groupId);
        if (products case Failure(:final error)) return Failure(error);
        final all = (products as Ok<List<Product>>).value;
        // A group that is gone has nobody to tell.
        final members = switch (await _groups.getGroup(groupId)) {
          Ok(:final value) => value.memberIds,
          Failure() => const <String>[],
        };
        final sent = await _service.closeTrip(
          open,
          notify: [
            for (final u in members)
              if (u != userId) u,
          ],
        );
        if (sent case Failure(:final error)) return Failure(error);
        final recorded = await _recordPlan([
          for (final p in [...all]..sort(byPosition))
            if (taken.contains(p.id)) p.id,
        ]);
        if (recorded case Failure(:final error)) return Failure(error);
        return Ok(taken.length);
      });
}

/// How many of the latest sent trips the one-off "recent" sort looks at.
const recentTripLimit = 50;

/// How many of the latest sent trips the history screen reads (one query, so the free
/// plan's daily reads are not spent on old trips).
const historyTripLimit = 200;

/// A repository of one given group, also for a group that is not shown now.
final listRepositoryForProvider = Provider.family<ListRepository, String>(
  (ref, groupId) => ListRepository(
    ref.watch(listServiceProvider),
    ref.watch(groupRepositoryProvider),
    groupId: groupId,
  ),
);
