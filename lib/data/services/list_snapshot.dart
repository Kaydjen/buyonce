import '../../domain/models/plan.dart';
import 'amount_codec.dart';
import 'money_codec.dart';
import '../../domain/models/product.dart';
import '../../domain/models/receipt.dart';
import '../../domain/models/trip.dart';
import '../../domain/models/trip_mark.dart';

/// The products, plans and trips of one list as plain JSON, so that the list of the
/// local mode (no account) can be kept on the device. Notices and asks are not kept:
/// the local list has no other member.
class ListSnapshot {
  const ListSnapshot({
    required this.products,
    required this.plans,
    required this.trips,
  });

  final List<Product> products;
  final List<Plan> plans;
  final List<Trip> trips;

  bool get isEmpty => products.isEmpty && plans.isEmpty && trips.isEmpty;

  Map<String, Object?> toJson() => {
    'products': [for (final p in products) _product(p)],
    'plans': [for (final p in plans) _plan(p)],
    'trips': [for (final t in trips) _trip(t)],
  };

  /// Null when the data is not a snapshot (damaged or from another version).
  static ListSnapshot? tryParse(Object? json) {
    try {
      final map = json as Map<String, dynamic>;
      return ListSnapshot(
        products: [
          for (final p in map['products'] as List) _parseProduct(p as Map),
        ],
        plans: [for (final p in map['plans'] as List) _parsePlan(p as Map)],
        trips: [for (final t in map['trips'] as List) _parseTrip(t as Map)],
      );
    } catch (_) {
      return null;
    }
  }

  static String? _time(DateTime? t) => t?.toUtc().toIso8601String();
  static DateTime? _parseTime(Object? s) =>
      s == null ? null : DateTime.parse(s as String).toLocal();

  static Map<String, Object?> _product(Product p) => {
    'id': p.id,
    'groupId': p.groupId,
    'name': p.name,
    'position': p.position,
    'planned': p.planned,
    'plannedBy': p.plannedBy,
    'plannedAt': _time(p.plannedAt),
    'usage': p.usage,
    if (p.deleted) ...{'deleted': true, 'deletedAt': _time(p.deletedAt)},
    if (!p.need.isNone) 'need': amountToData(p.need),
  };

  static Product _parseProduct(Map m) => Product(
    id: m['id'] as String,
    groupId: m['groupId'] as String,
    name: m['name'] as String,
    position: (m['position'] as num).toDouble(),
    planned: m['planned'] as bool,
    plannedBy: m['plannedBy'] as String?,
    plannedAt: _parseTime(m['plannedAt']),
    usage: m['usage'] as int,
    deleted: m['deleted'] == true,
    deletedAt: _parseTime(m['deletedAt']),
    need: amountFromData(m['need']),
  );

  static Map<String, Object?> _plan(Plan p) => {
    'id': p.id,
    'groupId': p.groupId,
    'productIds': p.productIds,
    'createdAt': _time(p.createdAt),
    'pinned': p.pinned,
  };

  static Plan _parsePlan(Map m) => Plan(
    id: m['id'] as String,
    groupId: m['groupId'] as String,
    productIds: [for (final id in m['productIds'] as List) id as String],
    createdAt: _parseTime(m['createdAt'])!,
    pinned: m['pinned'] as bool,
  );

  static Map<String, Object?> _trip(Trip t) => {
    'id': t.id,
    'groupId': t.groupId,
    'userId': t.userId,
    'startedAt': _time(t.startedAt),
    'sentAt': _time(t.sentAt),
    'autoSendAt': _time(t.autoSendAt),
    'marks': [
      for (final m in t.marks)
        {
          'productId': m.productId,
          'userId': m.userId,
          'markedAt': _time(m.markedAt),
          if (!m.amount.isNone) 'amount': amountToData(m.amount),
          if (m.price != null) 'price': moneyToData(m.price!),
          if (m.discount != null) 'discount': moneyToData(m.discount!),
          if (m.receiptText != null) 'receiptText': m.receiptText,
        },
    ],
    if (t.receipts.isNotEmpty)
      'receipts': [
        for (final r in t.receipts)
          {
            if (r.store != null) 'store': r.store,
            if (r.date != null) 'date': _time(r.date),
            if (r.total != null) 'total': moneyToData(r.total!),
            if (r.discount != null) 'discount': moneyToData(r.discount!),
          },
      ],
  };

  static Trip _parseTrip(Map m) => Trip(
    id: m['id'] as String,
    groupId: m['groupId'] as String,
    userId: m['userId'] as String,
    startedAt: _parseTime(m['startedAt'])!,
    sentAt: _parseTime(m['sentAt']),
    autoSendAt: _parseTime(m['autoSendAt']),
    marks: [
      for (final x in m['marks'] as List)
        TripMark(
          productId: (x as Map)['productId'] as String,
          userId: x['userId'] as String,
          markedAt: _parseTime(x['markedAt'])!,
          amount: amountFromData(x['amount']),
          price: moneyFromData(x['price']),
          discount: moneyFromData(x['discount']),
          receiptText: x['receiptText'] is String
              ? x['receiptText'] as String
              : null,
        ),
    ],
    receipts: [
      if (m['receipts'] is List)
        for (final r in m['receipts'] as List)
          if (r is Map)
            Receipt(
              store: r['store'] is String ? r['store'] as String : null,
              date: _parseTime(r['date']),
              total: moneyFromData(r['total']),
              discount: moneyFromData(r['discount']),
            ),
    ],
  );
}
