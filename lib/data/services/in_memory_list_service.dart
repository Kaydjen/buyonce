import 'package:flutter/foundation.dart';

import '../../core/utils/result.dart';
import '../../domain/models/group.dart';
import '../../domain/models/notice.dart';
import '../../domain/models/plan.dart';
import '../../domain/models/product.dart';
import '../../domain/models/trip.dart';
import '../../domain/models/trip_mark.dart';

/// Fake storage for the UX stage; replaced by a backend service later.
class InMemoryListService {
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
        position: i,
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

  Future<Result<List<Product>>> getProducts(String groupId) async =>
      Ok(_products.values.where((p) => p.groupId == groupId).toList());

  Future<Result<void>> putProduct(Product product) async {
    _products[product.id] = product;
    return const Ok<void>(null);
  }

  Future<Result<List<Plan>>> getPlans(String groupId) async =>
      Ok(_plans.values.where((p) => p.groupId == groupId).toList());

  Future<Result<void>> putPlan(Plan plan) async {
    _plans[plan.id] = plan;
    return const Ok<void>(null);
  }

  Future<Result<void>> deletePlan(String planId) async {
    _plans.remove(planId);
    return const Ok<void>(null);
  }

  Future<Result<List<Notice>>> getNotices(String groupId) async =>
      Ok(_notices.values.where((n) => n.groupId == groupId).toList());

  Future<Result<void>> putNotice(Notice notice) async {
    _notices[notice.id] = notice;
    return const Ok<void>(null);
  }

  Future<Result<List<Trip>>> getTrips(String groupId) async =>
      Ok(_trips.values.where((t) => t.groupId == groupId).toList());

  /// Every open trip of the group: one per user who has unsent marks.
  Future<Result<List<Trip>>> getOpenTrips(String groupId) async =>
      Ok(_trips.values.where((t) => t.groupId == groupId && t.isOpen).toList());

  Future<Result<void>> putTrip(Trip trip) async {
    _trips[trip.id] = trip;
    return const Ok<void>(null);
  }

  /// Removes everything the group owns.
  Future<Result<void>> deleteGroupData(String groupId) async {
    _products.removeWhere((_, p) => p.groupId == groupId);
    _plans.removeWhere((_, p) => p.groupId == groupId);
    _trips.removeWhere((_, t) => t.groupId == groupId);
    _notices.removeWhere((_, n) => n.groupId == groupId);
    return const Ok<void>(null);
  }

  /// A member left: the open trip and the unread notices of that user go; the sent
  /// trips stay, they are the group's history.
  Future<Result<void>> deleteMemberData(String groupId, String userId) async {
    _trips.removeWhere(
      (_, t) => t.groupId == groupId && t.userId == userId && t.isOpen,
    );
    _notices.removeWhere(
      (_, n) => n.groupId == groupId && n.toUserId == userId,
    );
    return const Ok<void>(null);
  }
}
