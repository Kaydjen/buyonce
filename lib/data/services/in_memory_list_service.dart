import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/utils/new_id.dart';
import '../../core/utils/result.dart';
import '../../domain/models/group.dart';
import '../../domain/models/notice.dart';
import '../../domain/models/plan.dart';
import '../../domain/models/product.dart';
import '../../domain/models/trip.dart';
import '../../domain/models/trip_mark.dart';
import 'list_service.dart';

/// Fake storage for the UX stage; replaced by a backend service later.
class InMemoryListService implements ListService {
  /// Debug builds start with the lists of the three seeded groups; release builds
  /// start empty (a new group has no products).
  InMemoryListService({bool? seed}) {
    if (!(seed ?? kDebugMode)) return;
    _seedGroup(
      defaultGroupId,
      products: _seed,
      planned: _seedPlanned,
      plans: _seedPlans,
      history: _history,
    );
    _seedGroup(
      'mom',
      products: _momSeed,
      planned: _momPlanned,
      plans: _momPlans,
      history: _momHistory,
    );
    _seedGroup(
      'work',
      products: _workSeed,
      planned: _workPlanned,
      plans: _workPlans,
      history: _workHistory,
    );
  }

  /// Ids of the first group stay `seed0`, `plan0`...; the others get a group prefix.
  void _seedGroup(
    String groupId, {
    required List<String> products,
    required Set<String> planned,
    required List<(List<String>, bool)> plans,
    required List<List<String>> history,
  }) {
    final prefix = groupId == defaultGroupId ? '' : '$groupId-';
    String idOf(String name) => '${prefix}seed${products.indexOf(name)}';
    for (var i = 0; i < products.length; i++) {
      _products['${prefix}seed$i'] = Product(
        id: '${prefix}seed$i',
        groupId: groupId,
        name: products[i],
        position: i.toDouble(),
        planned: planned.contains(products[i]),
      );
    }
    final now = DateTime.now();
    for (var i = 0; i < plans.length; i++) {
      final (names, pinned) = plans[i];
      _plans['${prefix}plan$i'] = Plan(
        id: '${prefix}plan$i',
        groupId: groupId,
        productIds: [for (final n in names) idOf(n)],
        createdAt: now.subtract(Duration(days: i + 1)),
        pinned: pinned,
      );
    }
    // Seeded usage = how many past trips contained the product.
    for (final trip in history) {
      for (final name in trip) {
        final id = idOf(name);
        _products[id] = _products[id]!.copyWith(
          usage: _products[id]!.usage + 1,
        );
      }
    }
    for (var i = 0; i < history.length; i++) {
      final at = now.subtract(Duration(days: history.length - i));
      // Every other past trip belongs to the partner, marks a few minutes apart.
      final user = i.isOdd ? 'partner' : 'me';
      _trips['${prefix}history$i'] = Trip(
        id: '${prefix}history$i',
        groupId: groupId,
        userId: user,
        startedAt: at,
        sentAt: at.add(const Duration(hours: 1)),
        marks: [
          for (var j = 0; j < history[i].length; j++)
            TripMark(
              productId: idOf(history[i][j]),
              userId: user,
              markedAt: at.add(Duration(minutes: 7 * j)),
            ),
        ],
      );
    }
  }

  static const _seed = [
    'Milk',
    'Bread',
    'Eggs',
    'Buns',
    'Salad',
    'Frozen vegetables',
    'Cheese',
    'Butter',
    'Kefir',
    'Cottage cheese',
    'Bananas',
    'Apples',
    'Tomatoes',
    'Cucumbers',
    'Potatoes',
    'Onions',
    'Chicken',
    'Yogurt',
    'Buckwheat',
    'Rice',
    'Pasta',
    'Coffee',
    'Tea',
    'Sour cream',
    'Ice cream',
    'Water',
    'Toilet paper',
  ];
  static const _seedPlanned = {'Milk', 'Frozen vegetables', 'Salad', 'Buns'};

  /// Past sent trips, oldest first; give the frequency sort something to count.
  static const _history = [
    ['Milk', 'Bread', 'Eggs', 'Kefir', 'Bananas'],
    ['Milk', 'Bread', 'Eggs', 'Cheese'],
    ['Milk', 'Bread', 'Kefir', 'Cottage cheese'],
    ['Milk', 'Bread', 'Eggs', 'Kefir', 'Apples'],
    ['Milk', 'Bread', 'Cheese'],
    ['Milk', 'Eggs', 'Bananas'],
  ];

  /// Seed plans: a pinned template and one past plan.
  static const _seedPlans = [
    (['Milk', 'Frozen vegetables', 'Salad', 'Buns'], true),
    (['Bread', 'Eggs', 'Cheese'], false),
  ];

  static const _momSeed = [
    'Milk',
    'Bread',
    'Potatoes',
    'Carrots',
    'Cabbage',
    'Sunflower oil',
    'Flour',
    'Sugar',
    'Tea',
    'Apples',
  ];
  static const _momPlanned = {'Bread', 'Carrots', 'Flour'};
  static const _momHistory = [
    ['Milk', 'Bread', 'Potatoes'],
    ['Bread', 'Sugar', 'Tea'],
    ['Milk', 'Bread', 'Apples'],
  ];
  static const _momPlans = [
    (['Bread', 'Carrots', 'Flour'], true),
  ];

  static const _workSeed = [
    'Coffee',
    'Tea',
    'Sugar',
    'Milk',
    'Cookies',
    'Paper cups',
    'Napkins',
    'Dish soap',
  ];
  static const _workPlanned = {'Coffee', 'Paper cups'};
  static const _workHistory = [
    ['Coffee', 'Milk', 'Sugar'],
    ['Coffee', 'Cookies'],
  ];
  static const _workPlans = [
    (['Coffee', 'Paper cups'], true),
  ];

  final Map<String, Plan> _plans = {};
  final Map<String, Product> _products = {};
  final Map<String, Trip> _trips = {};
  final Map<String, Notice> _notices = {};

  /// When each user last asked for products in each group, by `group/user`.
  final Map<String, DateTime> _askedAt = {};

  /// Change signals, `group/kind` (kind: products, trips, plans, notices) or `*`.
  final _changed = StreamController<String>.broadcast(sync: true);
  final _errors = StreamController<ListWriteError>.broadcast(sync: true);
  final _onlineChanges = StreamController<bool>.broadcast(sync: true);
  bool _isOnline = true;

  /// Test and debug switch: a write shows at once, then, after [ackDelay], the "server"
  /// refuses it: the data goes back and [writeErrors] reports it.
  bool failWrites = false;
  Duration ackDelay = const Duration(seconds: 1);

  /// Test and debug switch: the connection to the "server".
  void setOnline(bool online) {
    if (_isOnline == online) return;
    _isOnline = online;
    _onlineChanges.add(online);
  }

  @override
  Stream<bool> get online =>
      _stream(() => _isOnline, _onlineChanges.stream, (c, v) => c.add(v));

  @override
  Stream<ListWriteError> get writeErrors => _errors.stream;

  /// A stream that first emits the current value, then [onEvent] decides what a signal
  /// of [source] emits.
  Stream<T> _stream<T, S>(
    T Function() read,
    Stream<S> source,
    void Function(StreamController<T> c, S event) onEvent,
  ) {
    StreamSubscription<S>? sub;
    late final StreamController<T> controller;
    controller = StreamController<T>(
      sync: true,
      onListen: () {
        controller.add(read());
        sub = source.listen((event) => onEvent(controller, event));
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  Stream<Result<List<T>>> _watch<T>(
    String groupId,
    String kind,
    List<T> Function() read,
  ) => _stream<Result<List<T>>, String>(
    () => Ok(read()),
    _changed.stream.where((key) => key == '$groupId/$kind' || key == '*'),
    (c, _) => c.add(Ok(read())),
  );

  @override
  Stream<Result<List<Product>>> watchProducts(String groupId) =>
      _watch(groupId, 'products', () => _productsOf(groupId));

  @override
  Stream<Result<List<Trip>>> watchOpenTrips(String groupId) =>
      _watch(groupId, 'trips', () => _openTripsOf(groupId));

  @override
  Stream<Result<List<Plan>>> watchPlans(String groupId) =>
      _watch(groupId, 'plans', () => _plansOf(groupId));

  @override
  Stream<Result<List<Notice>>> watchNotices(String groupId) =>
      _watch(groupId, 'notices', () => _noticesOf(groupId));

  List<Product> _productsOf(String groupId) =>
      _products.values.where((p) => p.groupId == groupId).toList();

  List<Trip> _openTripsOf(String groupId) =>
      _trips.values.where((t) => t.groupId == groupId && t.isOpen).toList();

  List<Plan> _plansOf(String groupId) =>
      _plans.values.where((p) => p.groupId == groupId).toList();

  List<Notice> _noticesOf(String groupId) =>
      _notices.values.where((n) => n.groupId == groupId).toList();

  /// Applies a write locally and tells the listeners; with [failWrites] it is taken
  /// back later, like a write the server refuses.
  Result<void> _write(String groupId, String kind, void Function() apply) {
    final before = failWrites ? _Copy(this) : null;
    apply();
    return _finishWrite(groupId, before, [kind]);
  }

  Result<void> _finishWrite(String groupId, _Copy? before, List<String> kinds) {
    for (final kind in kinds) {
      _changed.add('$groupId/$kind');
    }
    if (before != null) {
      Timer(ackDelay, () {
        before.restore(this);
        _changed.add('*');
        _errors.add(ListWriteError(StateError('The server refused the write')));
      });
    }
    return const Ok<void>(null);
  }

  @override
  Future<Result<DateTime?>> getAskedAt(String groupId, String userId) async =>
      Ok(_askedAt['$groupId/$userId']);

  @override
  Future<Result<List<Product>>> getProducts(String groupId) async =>
      Ok(_productsOf(groupId));

  @override
  Future<Result<void>> createProduct(Product product) async => _write(
    product.groupId,
    'products',
    () => _products[product.id] = product.copyWith(usage: 0),
  );

  @override
  Future<Result<void>> updateProduct(Product product) async => _write(
    product.groupId,
    'products',
    () => _products[product.id] = product,
  );

  @override
  Future<Result<void>> updateProducts(List<Product> products) async {
    if (products.isEmpty) return const Ok<void>(null);
    return _write(products.first.groupId, 'products', () {
      for (final p in products) {
        _products[p.id] = p;
      }
    });
  }

  @override
  Future<Result<List<Plan>>> getPlans(String groupId) async =>
      Ok(_plansOf(groupId));

  @override
  Future<Result<void>> createPlan(Plan plan) async =>
      _write(plan.groupId, 'plans', () => _plans[plan.id] = plan);

  @override
  Future<Result<void>> updatePlan(Plan plan) async =>
      _write(plan.groupId, 'plans', () => _plans[plan.id] = plan);

  @override
  Future<Result<void>> deletePlan(Plan plan) async =>
      _write(plan.groupId, 'plans', () => _plans.remove(plan.id));

  @override
  Future<Result<List<Notice>>> getNotices(String groupId) async =>
      Ok(_noticesOf(groupId));

  @override
  Future<Result<void>> markNoticeSeen(Notice notice) async => _write(
    notice.groupId,
    'notices',
    () => _notices[notice.id] = notice.copyWith(seen: true),
  );

  @override
  Future<Result<List<Trip>>> getTrips(
    String groupId, {
    required int limit,
  }) async {
    final all = _trips.values.where((t) => t.groupId == groupId).toList();
    final sent = all.where((t) => !t.isOpen).toList()
      ..sort((a, b) => b.sentAt!.compareTo(a.sentAt!));
    return Ok([...all.where((t) => t.isOpen), ...sent.take(limit)]);
  }

  @override
  Future<Result<List<Trip>>> getOpenTrips(String groupId) async =>
      Ok(_openTripsOf(groupId));

  @override
  Future<Result<void>> createTrip(Trip trip) async =>
      _write(trip.groupId, 'trips', () => _trips[trip.id] = trip);

  @override
  Future<Result<void>> updateTripMarks(Trip trip) async =>
      _write(trip.groupId, 'trips', () => _trips[trip.id] = trip);

  /// Plays the server's part too: sent planned products leave the plan, count one more
  /// trip, and every recipient gets a notice.
  @override
  Future<Result<void>> closeTrip(
    Trip trip, {
    required List<String> notify,
  }) async {
    final taken = {for (final m in trip.marks) m.productId};
    final now = DateTime.now();
    final before = failWrites ? _Copy(this) : null;
    _trips[trip.id] = trip.copyWith(sentAt: now);
    for (final id in taken) {
      final p = _products[id];
      if (p != null) {
        _products[id] = p.copyWith(planned: false, usage: p.usage + 1);
      }
    }
    for (final other in notify) {
      final notice = Notice(
        id: newId(),
        groupId: trip.groupId,
        toUserId: other,
        fromUserId: trip.userId,
        productIds: taken.toList(),
        sentAt: now,
      );
      _notices[notice.id] = notice;
    }
    return _finishWrite(trip.groupId, before, ['trips', 'products', 'notices']);
  }

  @override
  Future<Result<void>> ask(
    String groupId,
    String userId,
    List<String> productIds, {
    required List<String> notify,
  }) async {
    final now = DateTime.now();
    for (final other in notify) {
      final notice = Notice(
        id: newId(),
        groupId: groupId,
        toUserId: other,
        fromUserId: userId,
        productIds: productIds,
        sentAt: now,
        kind: NoticeKind.needed,
      );
      _notices[notice.id] = notice;
    }
    _askedAt['$groupId/$userId'] = now;
    _changed.add('$groupId/notices');
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> deleteGroupData(String groupId) async {
    _products.removeWhere((_, p) => p.groupId == groupId);
    _plans.removeWhere((_, p) => p.groupId == groupId);
    _trips.removeWhere((_, t) => t.groupId == groupId);
    _notices.removeWhere((_, n) => n.groupId == groupId);
    _askedAt.removeWhere((key, _) => key.startsWith('$groupId/'));
    _changed.add('*');
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> deleteMemberData(String groupId, String userId) async {
    _trips.removeWhere(
      (_, t) => t.groupId == groupId && t.userId == userId && t.isOpen,
    );
    _notices.removeWhere(
      (_, n) => n.groupId == groupId && n.toUserId == userId,
    );
    _askedAt.remove('$groupId/$userId');
    _changed.add('*');
    return const Ok<void>(null);
  }
}

/// The stored data at one moment, to put it back when a write is refused.
class _Copy {
  _Copy(InMemoryListService s)
    : products = Map.of(s._products),
      plans = Map.of(s._plans),
      trips = Map.of(s._trips),
      notices = Map.of(s._notices),
      askedAt = Map.of(s._askedAt);

  final Map<String, Product> products;
  final Map<String, Plan> plans;
  final Map<String, Trip> trips;
  final Map<String, Notice> notices;
  final Map<String, DateTime> askedAt;

  void restore(InMemoryListService s) {
    s._products
      ..clear()
      ..addAll(products);
    s._plans
      ..clear()
      ..addAll(plans);
    s._trips
      ..clear()
      ..addAll(trips);
    s._notices
      ..clear()
      ..addAll(notices);
    s._askedAt
      ..clear()
      ..addAll(askedAt);
  }
}
