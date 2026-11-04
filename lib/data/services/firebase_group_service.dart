import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/invite_code.dart';
import '../../core/utils/result.dart';
import '../../domain/models/group.dart';
import 'group_service.dart';

/// One member document as the app reads it.
typedef MemberData = ({String userId, bool muted, DateTime joinedAt});

/// The group of a group document and its member documents; null when the document is
/// missing. Pure, so it is unit tested without Firestore.
Group? groupFromData(
  String id,
  Map<String, dynamic>? data,
  List<MemberData> members,
) {
  if (data == null) return null;
  final ordered = [...members]
    ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
  return Group(
    id: id,
    name: data['name'] as String? ?? '',
    utcOffset: Duration(minutes: (data['utcOffsetMin'] as num?)?.toInt() ?? 0),
    ownerId: data['ownerId'] as String? ?? '',
    memberIds: [for (final m in ordered) m.userId],
    inviteCode: data['inviteCode'] as String? ?? '',
    mutedUserIds: {
      for (final m in ordered)
        if (m.muted) m.userId,
    },
    personal: data['personal'] == true,
  );
}

/// A server time that has not come back yet reads as null: such a document is the
/// newest one.
DateTime timeOf(Object? value) =>
    value is Timestamp ? value.toDate() : DateTime.now();

MemberData memberFromData(Map<String, dynamic> data) => (
  userId: data['userId'] as String? ?? '',
  muted: data['muted'] == true,
  joinedAt: timeOf(data['joinedAt']),
);

/// Groups on Firestore, for the real signed-in user. Data model and rules:
/// `.ai/notes/backend-data-model.md`, `backend/firestore.rules`.
///
/// Creating, joining, leaving, removing and deleting need the server (a transaction
/// fails at once without a connection, so nothing waits in a queue and happens later
/// by surprise). Rename and mute are plain writes: they show at once and a refusal
/// arrives through [writeErrors].
class FirebaseGroupService implements GroupService {
  FirebaseGroupService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final _writeErrors = StreamController<Object>.broadcast();

  static const _timeout = Duration(seconds: 10);
  static final _codePattern = RegExp(r'^[A-Z0-9]{8}$');

  @override
  Stream<Object> get writeErrors => _writeErrors.stream;

  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('groups');

  CollectionReference<Map<String, dynamic>> get _codes =>
      _db.collection('joinCodes');

  CollectionReference<Map<String, dynamic>> _members(String groupId) =>
      _groups.doc(groupId).collection('members');

  /// A document from the local data; one that is not there asks the server (a document
  /// get from the cache throws when the document is not cached).
  Future<DocumentSnapshot<Map<String, dynamic>>> _docLocal(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      final cached = await ref.get(const GetOptions(source: Source.cache));
      if (cached.exists) return cached;
    } on FirebaseException {
      // Not cached.
    }
    return ref.get();
  }

  /// What the user can do about a failure: wait for the network, or nothing.
  static GroupError _errorOf(Object error) => switch (error) {
    TimeoutException() => GroupError.offline,
    FirebaseException(:final code)
        when code == 'unavailable' || code == 'deadline-exceeded' =>
      GroupError.offline,
    _ => GroupError.failed,
  };

  Future<Result<T>> _guard<T>(Future<Result<T>> Function() body) async {
    try {
      return await body();
    } catch (error) {
      return Failure(_errorOf(error));
    }
  }

  void _report(Future<void> write) {
    write.catchError((Object error) {
      _writeErrors.add(error);
    });
  }

  @override
  Stream<Result<List<Group>>> watchGroups(String userId) {
    late final StreamController<Result<List<Group>>> out;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? membership;
    final parts = <String, _GroupWatch>{};

    void emit() {
      if (out.isClosed || parts.values.any((p) => !p.ready)) return;
      final live = [
        for (final p in parts.values)
          if (p.group != null) p,
      ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      out.add(Ok([for (final p in live) p.group!]));
    }

    out = StreamController(
      onListen: () {
        membership = _db
            .collectionGroup('members')
            .where('userId', isEqualTo: userId)
            .snapshots()
            .listen((snapshot) {
              final ids = {
                for (final d in snapshot.docs) d.reference.parent.parent!.id,
              };
              for (final id in parts.keys.toList()) {
                if (!ids.contains(id)) parts.remove(id)!.cancel();
              }
              for (final id in ids) {
                parts.putIfAbsent(
                  id,
                  () => _GroupWatch(id, _groups.doc(id), _members(id), emit),
                );
              }
              emit();
            }, onError: (Object error) => out.add(Failure(_errorOf(error))));
      },
      onCancel: () async {
        await membership?.cancel();
        for (final p in parts.values) {
          p.cancel();
        }
        parts.clear();
      },
    );
    return out.stream;
  }

  @override
  Future<Result<List<Group>>> getGroups(String userId) =>
      _guard(() => watchGroups(userId).first);

  @override
  Future<Result<Group>> getGroup(String groupId) => _guard(() async {
    try {
      // The local data first: the live listeners keep it current for the user's groups,
      // so the app opens a known group without waiting for the network. Only a group
      // the local data does not know asks the server.
      final doc = await _docLocal(_groups.doc(groupId));
      var members = await _members(groupId)
          .get(const GetOptions(source: Source.cache));
      if (members.docs.isEmpty) members = await _members(groupId).get();
      final group = groupFromData(groupId, doc.data(), [
        for (final m in members.docs) memberFromData(m.data()),
      ]);
      return group == null ? const Failure(GroupError.notFound) : Ok(group);
    } on FirebaseException catch (e) {
      // A group the user is not in cannot be read: for them it does not exist.
      if (e.code == 'permission-denied') {
        return const Failure(GroupError.notFound);
      }
      rethrow;
    }
  });

  @override
  Future<Result<Group>> create({
    required String id,
    required String name,
    required Duration utcOffset,
    required String ownerId,
    bool personal = false,
  }) => _guard(() async {
    var code = '';
    await _db.runTransaction((tx) async {
      if (!personal) {
        do {
          code = newInviteCode();
        } while ((await tx.get(_codes.doc(code))).exists);
      }
      tx.set(_groups.doc(id), {
        'name': name,
        'utcOffsetMin': utcOffset.inMinutes,
        'ownerId': ownerId,
        'personal': personal,
        if (!personal) 'inviteCode': code,
        'memberCount': 1,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(_members(id).doc(ownerId), {
        'userId': ownerId,
        'joinedAt': FieldValue.serverTimestamp(),
        'muted': false,
      });
      if (!personal) tx.set(_codes.doc(code), {'groupId': id});
    }, timeout: _timeout);
    return getGroup(id);
  });

  @override
  Future<Result<Group>> join(String code, String userId) => _guard(() async {
    if (!_codePattern.hasMatch(code)) {
      return const Failure(GroupError.unknownCode);
    }
    final found = await _codes.doc(code).get();
    final groupId = found.data()?['groupId'] as String?;
    if (groupId == null) return const Failure(GroupError.unknownCode);
    // A member can read the group; for anybody else the read is refused.
    final already = await getGroup(groupId);
    if (already is Ok<Group>) return already;
    try {
      // The joiner cannot read the counter before joining, so it goes up by one.
      await _db.runTransaction((tx) async {
        tx.set(_members(groupId).doc(userId), {
          'userId': userId,
          'joinedAt': FieldValue.serverTimestamp(),
          'muted': false,
          'joinCode': code,
        });
        tx.update(_groups.doc(groupId), {
          'memberCount': FieldValue.increment(1),
        });
      }, timeout: _timeout);
    } on FirebaseException catch (e) {
      // The rules refuse a 21st member; nothing else is refused for a valid code.
      if (e.code == 'permission-denied') {
        return const Failure(GroupError.full);
      }
      rethrow;
    }
    return getGroup(groupId);
  });

  @override
  Future<Result<void>> rename(String groupId, String name) {
    _report(_groups.doc(groupId).update({'name': name}));
    return Future.value(const Ok(null));
  }

  @override
  Future<Result<void>> removeMember(
    String groupId,
    String userId, {
    String? newOwnerId,
  }) => _guard(() async {
    await _db.runTransaction((tx) async {
      tx.update(_groups.doc(groupId), {
        'memberCount': FieldValue.increment(-1),
        'ownerId': ?newOwnerId,
      });
      tx.delete(_members(groupId).doc(userId));
    }, timeout: _timeout);
    return const Ok<void>(null);
  });

  @override
  Future<Result<void>> setMuted(String groupId, String userId, bool muted) {
    _report(_members(groupId).doc(userId).update({'muted': muted}));
    return Future.value(const Ok(null));
  }

  /// Members, the join code and the group go in one commit. The products, trips,
  /// plans and notices inside stay behind unreadable (nobody is a member any more);
  /// removing them is not done here.
  @override
  Future<Result<void>> delete(String groupId) => _guard(() async {
    const fromServer = GetOptions(source: Source.server);
    final group = await _groups.doc(groupId).get(fromServer);
    if (!group.exists) return const Ok<void>(null);
    final members = await _members(groupId).get(fromServer);
    final code = group.data()?['inviteCode'] as String?;
    await _db.runTransaction((tx) async {
      for (final m in members.docs) {
        tx.delete(m.reference);
      }
      if (code != null && code.isNotEmpty) tx.delete(_codes.doc(code));
      tx.delete(group.reference);
    }, timeout: _timeout);
    return const Ok<void>(null);
  });
}

/// The two listeners of one group (its document and its members) and what they
/// brought last.
class _GroupWatch {
  _GroupWatch(
    this._id,
    DocumentReference<Map<String, dynamic>> doc,
    CollectionReference<Map<String, dynamic>> members,
    void Function() changed,
  ) {
    _doc = doc.snapshots().listen(
      (s) {
        _data = s.data();
        _gotDoc = true;
        changed();
      },
      onError: (Object _) {
        // Refused after the user left: the group is gone for them.
        _data = null;
        _gotDoc = true;
        changed();
      },
    );
    _members = members.snapshots().listen(
      (s) {
        _memberData = [for (final d in s.docs) memberFromData(d.data())];
        _gotMembers = true;
        changed();
      },
      onError: (Object _) {
        _memberData = const [];
        _gotMembers = true;
        changed();
      },
    );
  }

  final String _id;
  late final StreamSubscription<Object?> _doc;
  late final StreamSubscription<Object?> _members;
  Map<String, dynamic>? _data;
  List<MemberData> _memberData = const [];
  bool _gotDoc = false;
  bool _gotMembers = false;

  bool get ready => _gotDoc && _gotMembers;

  DateTime get createdAt => timeOf(_data?['createdAt']);

  Group? get group => groupFromData(_id, _data, _memberData);

  void cancel() {
    _doc.cancel();
    _members.cancel();
  }
}
