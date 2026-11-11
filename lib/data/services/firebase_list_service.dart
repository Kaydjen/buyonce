import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/utils/result.dart';
import '../../domain/models/amount.dart';
import '../../domain/models/notice.dart';
import '../../domain/models/plan.dart';
import '../../domain/models/product.dart';
import '../../domain/models/receipt.dart';
import '../../domain/models/trip.dart';
import '../../domain/models/trip_mark.dart';
import 'amount_codec.dart';
import 'money_codec.dart';
import 'list_service.dart';
import 'send_worker.dart';

typedef Doc = Map<String, dynamic>;

/// A server time that has not come back yet reads as null: the document is brand new.
DateTime _time(Object? value) =>
    value is Timestamp ? value.toDate() : DateTime.now();

/// The time of my last ask. The server stamps it, so right after the write it is still
/// null in the local data: with the write pending that is "just now", not "never"
/// (otherwise the products just announced would count as new again).
DateTime? askedAtFromData(Object? value, {required bool hasPendingWrites}) {
  if (value is Timestamp) return value.toDate();
  return hasPendingWrites ? DateTime.now() : null;
}

Product productFromData(String groupId, String id, Doc data) => Product(
  id: id,
  groupId: groupId,
  name: data['name'] as String? ?? '',
  position: (data['position'] as num?)?.toDouble() ?? 0,
  planned: data['planned'] == true,
  plannedBy: data['plannedBy'] as String?,
  plannedAt: data['planned'] == true ? _time(data['plannedAt']) : null,
  usage: (data['usage'] as num?)?.toInt() ?? 0,
  deleted: data['deleted'] == true,
  deletedAt: data['deleted'] == true && data['deletedAt'] != null
      ? _time(data['deletedAt'])
      : null,
  need: data['planned'] == true ? amountFromData(data['need']) : Amount.none,
);

Trip tripFromData(String groupId, String id, Doc data) {
  final userId = data['userId'] as String? ?? '';
  final marks = (data['marks'] as Map?) ?? const {};
  return Trip(
    id: id,
    groupId: groupId,
    userId: userId,
    startedAt: _time(data['startedAt']),
    marks: [
      for (final e in marks.entries)
        TripMark(
          productId: e.key as String,
          userId: userId,
          // An old mark is the bare time; one with an amount is a map {at, count, g, ml}.
          markedAt: _time(e.value is Map ? (e.value as Map)['at'] : e.value),
          amount: amountFromData(e.value),
          price: e.value is Map ? moneyFromData((e.value as Map)['price']) : null,
          discount: e.value is Map
              ? moneyFromData((e.value as Map)['discount'])
              : null,
        ),
    ]..sort((a, b) => a.markedAt.compareTo(b.markedAt)),
    sentAt: data['sentAt'] == null ? null : _time(data['sentAt']),
    autoSendAt: data['autoSendAt'] == null ? null : _time(data['autoSendAt']),
    receipts: receiptsFromData(data['receipts']),
  );
}

/// `receipts` = a list of maps `{store, date, total, discount}`, every key optional;
/// an unreadable entry is skipped.
List<Receipt> receiptsFromData(Object? data) => [
  if (data is List)
    for (final r in data)
      if (r is Map)
        Receipt(
          store: r['store'] is String ? r['store'] as String : null,
          date: r['date'] == null ? null : _time(r['date']),
          total: moneyFromData(r['total']),
          discount: moneyFromData(r['discount']),
        ),
];

List<Map<String, Object>> receiptsToData(List<Receipt> receipts) => [
  for (final r in receipts)
    {
      if (r.store != null) 'store': r.store!,
      if (r.date != null) 'date': Timestamp.fromDate(r.date!),
      if (r.total != null) 'total': moneyToData(r.total!),
      if (r.discount != null) 'discount': moneyToData(r.discount!),
    },
];

/// `marks.<productId>` = when the product was taken: the bare time while nothing else
/// is known (so a phone with an older version still reads it), else a map
/// `{at, count, g, ml, price, discount}` with only the known parts.
Map<String, Object> marksToData(List<TripMark> marks) => {
  for (final m in marks)
    m.productId: m.amount.isNone && m.price == null && m.discount == null
        ? Timestamp.fromDate(m.markedAt)
        : {
            'at': Timestamp.fromDate(m.markedAt),
            ...amountToData(m.amount),
            if (m.price != null) 'price': moneyToData(m.price!),
            if (m.discount != null) 'discount': moneyToData(m.discount!),
          },
};

Plan planFromData(String groupId, String id, Doc data) => Plan(
  id: id,
  groupId: groupId,
  productIds: [for (final p in (data['productIds'] as List? ?? const [])) '$p'],
  createdAt: _time(data['createdAt']),
  pinned: data['pinned'] == true,
);

Notice noticeFromData(String groupId, String id, Doc data) => Notice(
  id: id,
  groupId: groupId,
  toUserId: data['toUserId'] as String? ?? '',
  fromUserId: data['fromUserId'] as String? ?? '',
  productIds: [for (final p in (data['productIds'] as List? ?? const [])) '$p'],
  sentAt: _time(data['sentAt']),
  kind: data['kind'] == 'needed' ? NoticeKind.needed : NoticeKind.bought,
  seen: data['seen'] == true,
);

/// The write of a changed need, field by field (`need.g`, `need.ml`, `need.count`):
/// what is not set is deleted explicitly, so a switch from litres to kilos can never
/// leave the old measure beside the new one, however the local copy merges the map.
Map<String, Object?> needChange(Amount need) => need.isNone
    ? {'need': FieldValue.delete()}
    : {
        'need.count': need.count == 1 ? FieldValue.delete() : need.count,
        'need.g': need.grams ?? FieldValue.delete(),
        'need.ml': need.millilitres ?? FieldValue.delete(),
      };

/// What an update of a product writes (never `usage`). Planning stamps the planner and
/// the server time, un-planning removes both; a product that stays planned keeps them,
/// because the rules refuse a change of either.
Map<String, Object?> productChange(
  Product p, {
  required bool wasPlanned,
  bool wasDeleted = false,
  Amount wasNeed = Amount.none,
  required String me,
}) => {
  'name': p.name,
  'position': p.position,
  'planned': p.planned,
  if (p.planned && !wasPlanned) ...{
    'plannedBy': p.plannedBy ?? me,
    'plannedAt': FieldValue.serverTimestamp(),
  },
  if (!p.planned && wasPlanned) ...{
    'plannedBy': FieldValue.delete(),
    'plannedAt': FieldValue.delete(),
  },
  if (p.deleted && !wasDeleted) ...{
    'deleted': true,
    'deletedAt': FieldValue.serverTimestamp(),
  },
  if (!p.deleted && wasDeleted) ...{
    'deleted': FieldValue.delete(),
    'deletedAt': FieldValue.delete(),
  },
  // The need lives only while the product is planned (the rules check it too); it is
  // written only when it changes.
  if (p.need != wasNeed) ...needChange(p.need),
};

/// Products, trips, plans and notices of the groups on Firestore, for the real
/// signed-in user (`.ai/notes/backend-data-model.md`, `backend/firestore.rules`).
///
/// Writes are local-first: they are applied to the local data at once and sent in the
/// background; a refusal arrives through [writeErrors]. The getters read the local data
/// (kept fresh by the live listeners); only the history asks the server.
class FirebaseListService implements ListService {
  FirebaseListService({
    FirebaseFirestore? db,
    String Function()? uid,
    SendWorker? worker,
  }) : _worker = worker, // ignore: prefer_initializing_formals
       _db = db ?? FirebaseFirestore.instance,
       _uid = uid ?? (() => FirebaseAuth.instance.currentUser?.uid ?? '');

  final FirebaseFirestore _db;
  final String Function() _uid;
  final SendWorker? _worker;

  final _errors = StreamController<ListWriteError>.broadcast();
  final _onlineChanges = StreamController<bool>.broadcast();
  bool _isOnline = true;
  Timer? _offlineTimer;

  static const _offlineAfter = Duration(seconds: 3);

  /// `group/kind` of the collections a live listener is attached to: their local data
  /// is current, so a getter answers from it even when it is empty (a trip that does
  /// not exist yet is the usual case before the first mark).
  final _warm = <String, int>{};

  CollectionReference<Doc> _col(String groupId, String name) =>
      _db.collection('groups').doc(groupId).collection(name);

  DocumentReference<Doc> _member(String groupId, String userId) =>
      _col(groupId, 'members').doc(userId);

  @override
  Stream<ListWriteError> get writeErrors => _errors.stream;

  @override
  Stream<bool> get online {
    late final StreamController<bool> controller;
    StreamSubscription<bool>? sub;
    controller = StreamController<bool>(
      onListen: () {
        controller.add(_isOnline);
        sub = _onlineChanges.stream.listen(controller.add);
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  void _setOnline(bool value) {
    if (_isOnline == value) return;
    _isOnline = value;
    _onlineChanges.add(value);
  }

  /// A snapshot that comes from the cache for longer than [_offlineAfter] means the
  /// server cannot be reached; one from the server means it can.
  void _reportSource(SnapshotMetadata metadata) {
    if (!metadata.isFromCache) {
      _offlineTimer?.cancel();
      _offlineTimer = null;
      _setOnline(true);
    } else {
      _offlineTimer ??= Timer(_offlineAfter, () => _setOnline(false));
    }
  }

  void _report(Future<void> write) {
    write.catchError((Object error) {
      _errors.add(ListWriteError(error));
    });
  }

  Stream<Result<List<T>>> _watch<T>(
    Query<Doc> query,
    T Function(String id, Doc data) parse, {
    bool reportsOnline = false,
    String? warmKey,
  }) {
    late final StreamController<Result<List<T>>> controller;
    StreamSubscription<QuerySnapshot<Doc>>? data;
    StreamSubscription<QuerySnapshot<Doc>>? meta;
    controller = StreamController(
      onListen: () {
        if (warmKey != null) _warm[warmKey] = (_warm[warmKey] ?? 0) + 1;
        data = query.snapshots().listen(
          (snap) => controller.add(
            Ok([for (final d in snap.docs) parse(d.id, d.data())]),
          ),
          onError: (Object error) => controller.add(Failure(error)),
        );
        if (reportsOnline) {
          meta = query
              .snapshots(includeMetadataChanges: true)
              .listen((snap) => _reportSource(snap.metadata), onError: (_) {});
        }
      },
      onCancel: () async {
        if (warmKey != null) {
          final left = (_warm[warmKey] ?? 1) - 1;
          if (left <= 0) {
            _warm.remove(warmKey);
          } else {
            _warm[warmKey] = left;
          }
        }
        await data?.cancel();
        await meta?.cancel();
      },
    );
    return controller.stream;
  }

  /// A document from the local data; one that is not there asks the server (a document
  /// get from the cache throws when the document is not cached).
  Future<DocumentSnapshot<Doc>> _docLocal(DocumentReference<Doc> ref) async {
    try {
      final cached = await ref.get(const GetOptions(source: Source.cache));
      if (cached.exists) return cached;
    } on FirebaseException {
      // Not cached.
    }
    return ref.get();
  }

  /// The local data; when no listener keeps this collection current and the local data
  /// has nothing, one read that may ask the server.
  Future<QuerySnapshot<Doc>> _local(Query<Doc> query, String warmKey) async {
    final cached = await query.get(const GetOptions(source: Source.cache));
    if (cached.docs.isNotEmpty || _warm.containsKey(warmKey)) return cached;
    return query.get();
  }

  Future<Result<T>> _guard<T>(Future<T> Function() body) async {
    try {
      return Ok(await body());
    } catch (error) {
      return Failure(error);
    }
  }

  @override
  Stream<Result<List<Product>>> watchProducts(String groupId) => _watch(
    _col(groupId, 'products'),
    (id, d) => productFromData(groupId, id, d),
    reportsOnline: true,
    warmKey: '$groupId/products',
  );

  @override
  Stream<Result<List<Trip>>> watchOpenTrips(String groupId) => _watch(
    _col(groupId, 'trips').where('open', isEqualTo: true),
    (id, d) => tripFromData(groupId, id, d),
    warmKey: '$groupId/trips',
  );

  @override
  Stream<Result<List<Plan>>> watchPlans(String groupId) => _watch(
    _col(groupId, 'plans'),
    (id, d) => planFromData(groupId, id, d),
    warmKey: '$groupId/plans',
  );

  /// The rules show a member only the notices meant for them.
  @override
  Stream<Result<List<Notice>>> watchNotices(String groupId) => _watch(
    _col(groupId, 'notices').where('toUserId', isEqualTo: _uid()),
    (id, d) => noticeFromData(groupId, id, d),
    warmKey: '$groupId/notices',
  );

  @override
  Future<Result<DateTime?>> getAskedAt(String groupId, String userId) =>
      _guard(() async {
        final doc = await _docLocal(_member(groupId, userId));
        return askedAtFromData(
          doc.data()?['askedAt'],
          hasPendingWrites: doc.metadata.hasPendingWrites,
        );
      });

  @override
  Future<Result<List<Product>>> getProducts(String groupId) => _guard(
    () async => [
      for (final d in (await _local(
        _col(groupId, 'products'),
        '$groupId/products',
      )).docs)
        productFromData(groupId, d.id, d.data()),
    ],
  );

  @override
  Future<Result<void>> createProduct(Product product) async {
    final planned = product.planned;
    _report(
      _col(product.groupId, 'products').doc(product.id).set({
        'name': product.name,
        'position': product.position,
        'planned': planned,
        if (planned) ...{
          'plannedBy': product.plannedBy ?? _uid(),
          'plannedAt': FieldValue.serverTimestamp(),
        },
        'usage': 0,
      }),
    );
    return const Ok<void>(null);
  }

  /// Which of the products are planned and which deleted now, by id, from the local
  /// data.
  Future<Map<String, ({bool planned, bool deleted, Amount need})>> _stateNow(
    String groupId,
  ) async => {
    for (final d in (await _local(
      _col(groupId, 'products'),
      '$groupId/products',
    )).docs)
      d.id: (
        planned: d.data()['planned'] == true,
        deleted: d.data()['deleted'] == true,
        need: amountFromData(d.data()['need']),
      ),
  };

  @override
  Future<Result<void>> updateProduct(Product product) =>
      updateProducts([product]);

  @override
  Future<Result<void>> updateProducts(List<Product> products) =>
      _guard(() async {
        if (products.isEmpty) return;
        final groupId = products.first.groupId;
        final now = await _stateNow(groupId);
        final batch = _db.batch();
        for (final p in products) {
          batch.update(
            _col(groupId, 'products').doc(p.id),
            productChange(
              p,
              wasPlanned: now[p.id]?.planned ?? false,
              wasDeleted: now[p.id]?.deleted ?? false,
              wasNeed: now[p.id]?.need ?? Amount.none,
              me: _uid(),
            ),
          );
        }
        _report(batch.commit());
      });

  @override
  Future<Result<List<Plan>>> getPlans(String groupId) => _guard(
    () async => [
      for (final d in (await _local(
        _col(groupId, 'plans'),
        '$groupId/plans',
      )).docs)
        planFromData(groupId, d.id, d.data()),
    ],
  );

  @override
  Future<Result<void>> createPlan(Plan plan) async {
    _report(
      _col(plan.groupId, 'plans').doc(plan.id).set({
        'productIds': plan.productIds,
        'createdAt': FieldValue.serverTimestamp(),
        'pinned': plan.pinned,
      }),
    );
    return const Ok<void>(null);
  }

  /// A new date is the server's time; a plan whose date did not change keeps it.
  @override
  Future<Result<void>> updatePlan(Plan plan) => _guard(() async {
    final ref = _col(plan.groupId, 'plans').doc(plan.id);
    final doc = await _docLocal(ref);
    final stored = doc.data()?['createdAt'];
    final dateChanged =
        stored is! Timestamp ||
        stored.millisecondsSinceEpoch != plan.createdAt.millisecondsSinceEpoch;
    _report(
      ref.update({
        'pinned': plan.pinned,
        if (dateChanged) 'createdAt': FieldValue.serverTimestamp(),
      }),
    );
  });

  @override
  Future<Result<void>> deletePlan(Plan plan) async {
    _report(_col(plan.groupId, 'plans').doc(plan.id).delete());
    return const Ok<void>(null);
  }

  @override
  Future<Result<List<Notice>>> getNotices(String groupId) => _guard(
    () async => [
      for (final d in (await _local(
        _col(groupId, 'notices').where('toUserId', isEqualTo: _uid()),
        '$groupId/notices',
      )).docs)
        noticeFromData(groupId, d.id, d.data()),
    ],
  );

  @override
  Future<Result<void>> markNoticeSeen(Notice notice) async {
    _report(
      _col(notice.groupId, 'notices').doc(notice.id).update({'seen': true}),
    );
    return const Ok<void>(null);
  }

  /// The open trips and the latest sent ones. The history is not on the tap path, so it
  /// asks the server (the cache falls in when there is no connection).
  @override
  Future<Result<List<Trip>>> getTrips(String groupId, {required int limit}) =>
      _guard(() async {
        final open = await _col(
          groupId,
          'trips',
        ).where('open', isEqualTo: true).get();
        final sent = await _col(
          groupId,
          'trips',
        ).orderBy('sentAt', descending: true).limit(limit).get();
        return [
          for (final d in [...open.docs, ...sent.docs])
            tripFromData(groupId, d.id, d.data()),
        ];
      });

  @override
  Future<Result<List<Trip>>> getOpenTrips(String groupId) => _guard(
    () async => [
      for (final d in (await _local(
        _col(groupId, 'trips').where('open', isEqualTo: true),
        '$groupId/trips',
      )).docs)
        tripFromData(groupId, d.id, d.data()),
    ],
  );

  @override
  Future<Result<void>> createTrip(Trip trip) async {
    _report(
      _col(trip.groupId, 'trips').doc(trip.id).set({
        'userId': trip.userId,
        'startedAt': FieldValue.serverTimestamp(),
        'marks': marksToData(trip.marks),
        if (trip.receipts.isNotEmpty) 'receipts': receiptsToData(trip.receipts),
        'open': true,
        if (trip.autoSendAt != null)
          'autoSendAt': Timestamp.fromDate(trip.autoSendAt!),
      }),
    );
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> updateTripMarks(Trip trip) async {
    _report(
      _col(
        trip.groupId,
        'trips',
      ).doc(trip.id).update({
        'marks': marksToData(trip.marks),
        if (trip.receipts.isNotEmpty) 'receipts': receiptsToData(trip.receipts),
      }),
    );
    return const Ok<void>(null);
  }

  /// How long the server waits for the phone's own call before it sends the trip itself.
  static const sendLease = Duration(minutes: 2);

  @override
  Future<Result<void>> setAutoSendAt(Trip trip, DateTime? at) async {
    _report(
      _col(trip.groupId, 'trips').doc(trip.id).update({
        'autoSendAt': at == null ? FieldValue.delete() : Timestamp.fromDate(at),
      }),
    );
    return const Ok<void>(null);
  }

  /// One batch: the trip closes (server time) and the planned flags of its products
  /// clear, so this phone shows the result at once. The lease `autoSendAt` makes the
  /// server finish the send if the call below does not get through. The count in
  /// `usage`, the notices and the push are the Worker's.
  @override
  Future<Result<void>> closeTrip(Trip trip, {required List<String> notify}) =>
      _guard(() async {
        final now = await _stateNow(trip.groupId);
        final batch = _db.batch();
        batch.update(_col(trip.groupId, 'trips').doc(trip.id), {
          'sentAt': FieldValue.serverTimestamp(),
          'open': false,
          'autoSendAt': Timestamp.fromDate(DateTime.now().add(sendLease)),
        });
        for (final m in trip.marks) {
          if (now[m.productId]?.planned == true) {
            batch.update(_col(trip.groupId, 'products').doc(m.productId), {
              'planned': false,
              'plannedBy': FieldValue.delete(),
              'plannedAt': FieldValue.delete(),
              'need': FieldValue.delete(),
            });
          }
        }
        final committed = batch.commit();
        _report(committed);
        // Only a trip the server has seen closed can be finished; offline this waits.
        final worker = _worker;
        if (worker != null) {
          unawaited(
            committed
                .then((_) => worker.finishSend(trip.groupId, trip.id))
                .catchError((Object _) {}),
          );
        }
      });

  /// Stamps the time of the ask (server time); once the server has it, the Worker is
  /// called and answers the ask only if the stamp is fresh. Notices and push are its.
  @override
  Future<Result<void>> ask(
    String groupId,
    String userId,
    List<String> productIds, {
    required List<String> notify,
  }) async {
    final stamped = _member(
      groupId,
      userId,
    ).update({'askedAt': FieldValue.serverTimestamp()});
    _report(stamped);
    final worker = _worker;
    if (worker != null) {
      unawaited(
        stamped
            .then((_) => worker.finishAsk(groupId, productIds))
            .catchError((Object _) {}),
      );
    }
    return const Ok<void>(null);
  }

  Future<void> _deleteAll(Iterable<DocumentReference<Doc>> refs) async {
    final all = refs.toList();
    for (var i = 0; i < all.length; i += 400) {
      final batch = _db.batch();
      for (final ref in all.skip(i).take(400)) {
        batch.delete(ref);
      }
      await batch.commit().timeout(const Duration(seconds: 10));
    }
  }

  /// The owner's call. Notices of the other members cannot be listed by a client (the
  /// rules show a member only their own), so those stay behind unreadable.
  @override
  Future<Result<void>> deleteGroupData(String groupId) => _guard(() async {
    for (final name in ['products', 'trips', 'plans']) {
      final docs = await _col(
        groupId,
        name,
      ).get(const GetOptions(source: Source.server));
      await _deleteAll(docs.docs.map((d) => d.reference));
    }
    final own = await _col(groupId, 'notices')
        .where('toUserId', isEqualTo: _uid())
        .get(const GetOptions(source: Source.server));
    await _deleteAll(own.docs.map((d) => d.reference));
  });

  /// The open trip of the user and, when it is the user's own call, their notices; run
  /// before the member leaves (afterwards the rules would refuse it).
  @override
  Future<Result<void>> deleteMemberData(String groupId, String userId) =>
      _guard(() async {
        final trips = await _col(groupId, 'trips')
            .where('userId', isEqualTo: userId)
            .where('open', isEqualTo: true)
            .get(const GetOptions(source: Source.server));
        await _deleteAll(trips.docs.map((d) => d.reference));
        if (userId == _uid()) {
          final own = await _col(groupId, 'notices')
              .where('toUserId', isEqualTo: userId)
              .get(const GetOptions(source: Source.server));
          await _deleteAll(own.docs.map((d) => d.reference));
        }
      });
}
