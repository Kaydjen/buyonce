import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/utils/result.dart';
import '../../domain/models/notice.dart';
import '../../domain/models/plan.dart';
import '../../domain/models/product.dart';
import '../../domain/models/trip.dart';
import '../../domain/models/trip_mark.dart';
import 'list_service.dart';

typedef Doc = Map<String, dynamic>;

/// A server time that has not come back yet reads as null: the document is brand new.
DateTime _time(Object? value) =>
    value is Timestamp ? value.toDate() : DateTime.now();

Product productFromData(String groupId, String id, Doc data) => Product(
  id: id,
  groupId: groupId,
  name: data['name'] as String? ?? '',
  position: (data['position'] as num?)?.toDouble() ?? 0,
  planned: data['planned'] == true,
  plannedBy: data['plannedBy'] as String?,
  plannedAt: data['planned'] == true ? _time(data['plannedAt']) : null,
  usage: (data['usage'] as num?)?.toInt() ?? 0,
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
          markedAt: _time(e.value),
        ),
    ]..sort((a, b) => a.markedAt.compareTo(b.markedAt)),
    sentAt: data['sentAt'] == null ? null : _time(data['sentAt']),
  );
}

/// `marks.<productId>` = when the product was taken.
Map<String, Timestamp> marksToData(List<TripMark> marks) => {
  for (final m in marks) m.productId: Timestamp.fromDate(m.markedAt),
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

/// What an update of a product writes (never `usage`). Planning stamps the planner and
/// the server time, un-planning removes both; a product that stays planned keeps them,
/// because the rules refuse a change of either.
Map<String, Object?> productChange(
  Product p, {
  required bool wasPlanned,
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
};

/// Products, trips, plans and notices of the groups on Firestore, for the real
/// signed-in user (`.ai/notes/backend-data-model.md`, `backend/firestore.rules`).
///
/// Writes are local-first: they are applied to the local data at once and sent in the
/// background; a refusal arrives through [writeErrors]. The getters read the local data
/// (kept fresh by the live listeners); only the history asks the server.
class FirebaseListService implements ListService {
  FirebaseListService({FirebaseFirestore? db, String Function()? uid})
    : _db = db ?? FirebaseFirestore.instance,
      _uid = uid ?? (() => FirebaseAuth.instance.currentUser?.uid ?? '');

  final FirebaseFirestore _db;
  final String Function() _uid;

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
        final at = doc.data()?['askedAt'];
        return at == null ? null : _time(at);
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

  /// Which of the products are planned now, by id, from the local data.
  Future<Map<String, bool>> _plannedNow(String groupId) async => {
    for (final d in (await _local(
      _col(groupId, 'products'),
      '$groupId/products',
    )).docs)
      d.id: d.data()['planned'] == true,
  };

  @override
  Future<Result<void>> updateProduct(Product product) =>
      updateProducts([product]);

  @override
  Future<Result<void>> updateProducts(List<Product> products) =>
      _guard(() async {
        if (products.isEmpty) return;
        final groupId = products.first.groupId;
        final planned = await _plannedNow(groupId);
        final batch = _db.batch();
        for (final p in products) {
          batch.update(
            _col(groupId, 'products').doc(p.id),
            productChange(p, wasPlanned: planned[p.id] ?? false, me: _uid()),
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
        'open': true,
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
      ).doc(trip.id).update({'marks': marksToData(trip.marks)}),
    );
    return const Ok<void>(null);
  }

  /// One batch: the trip closes (server time) and the planned flags of its products
  /// clear. The count in `usage` and the notices are the Worker's (step 61).
  @override
  Future<Result<void>> closeTrip(Trip trip, {required List<String> notify}) =>
      _guard(() async {
        final planned = await _plannedNow(trip.groupId);
        final batch = _db.batch();
        batch.update(_col(trip.groupId, 'trips').doc(trip.id), {
          'sentAt': FieldValue.serverTimestamp(),
          'open': false,
        });
        for (final m in trip.marks) {
          if (planned[m.productId] == true) {
            batch.update(_col(trip.groupId, 'products').doc(m.productId), {
              'planned': false,
              'plannedBy': FieldValue.delete(),
              'plannedAt': FieldValue.delete(),
            });
          }
        }
        _report(batch.commit());
      });

  /// Stamps the time of the ask; the notices are the Worker's (step 61).
  @override
  Future<Result<void>> ask(
    String groupId,
    String userId,
    List<String> productIds, {
    required List<String> notify,
  }) async {
    _report(
      _member(
        groupId,
        userId,
      ).update({'askedAt': FieldValue.serverTimestamp()}),
    );
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
