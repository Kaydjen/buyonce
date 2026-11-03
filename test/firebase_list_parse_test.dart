import 'package:buyonce/data/services/firebase_list_service.dart';
import 'package:buyonce/domain/models/notice.dart';
import 'package:buyonce/domain/models/product.dart';
import 'package:buyonce/domain/models/trip_mark.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime.utc(2026, 11, 1, 10);

  test(
    'a product document makes a Product, a pending server time counts as now',
    () {
      final p = productFromData('g', 'p1', {
        'name': 'Milk',
        'position': 2,
        'planned': true,
        'plannedBy': 'alice',
        'plannedAt': Timestamp.fromDate(t0),
        'usage': 3,
      });
      expect(p.name, 'Milk');
      expect(p.position, 2.0);
      expect(p.planned, isTrue);
      expect(p.plannedBy, 'alice');
      expect(p.plannedAt!.isAtSameMomentAs(t0), isTrue);
      expect(p.usage, 3);

      final pending = productFromData('g', 'p2', {
        'name': 'Tea',
        'position': 0.5,
        'planned': true,
        'plannedBy': 'alice',
        'plannedAt': null,
      });
      expect(pending.plannedAt, isNotNull);
      expect(pending.usage, 0);

      final plain = productFromData('g', 'p3', {
        'name': 'Salt',
        'position': 1,
        'planned': false,
      });
      expect(plain.plannedAt, isNull);
    },
  );

  test('a trip document: marks are a map, the mark user is the trip user', () {
    final trip = tripFromData('g', 't1', {
      'userId': 'bob',
      'startedAt': Timestamp.fromDate(t0),
      'open': true,
      'marks': {
        'b': Timestamp.fromDate(t0.add(const Duration(minutes: 5))),
        'a': Timestamp.fromDate(t0),
      },
    });
    expect(trip.isOpen, isTrue);
    expect([for (final m in trip.marks) m.productId], ['a', 'b']);
    expect(trip.marks.every((m) => m.userId == 'bob'), isTrue);

    final sent = tripFromData('g', 't2', {
      'userId': 'bob',
      'startedAt': Timestamp.fromDate(t0),
      'sentAt': Timestamp.fromDate(t0),
      'open': false,
      'marks': <String, Object?>{},
    });
    expect(sent.isOpen, isFalse);
  });

  test('marks are written as productId -> time', () {
    final data = marksToData([
      TripMark(productId: 'a', userId: 'bob', markedAt: t0),
    ]);
    expect(data.keys, ['a']);
    expect(data['a']!.toDate().isAtSameMomentAs(t0), isTrue);
  });

  test('plan and notice documents', () {
    final plan = planFromData('g', 'pl', {
      'productIds': ['a', 'b'],
      'createdAt': Timestamp.fromDate(t0),
      'pinned': true,
    });
    expect(plan.productIds, ['a', 'b']);
    expect(plan.pinned, isTrue);

    final notice = noticeFromData('g', 'n', {
      'toUserId': 'bob',
      'fromUserId': 'alice',
      'productIds': ['a'],
      'sentAt': Timestamp.fromDate(t0),
      'kind': 'needed',
      'seen': false,
    });
    expect(notice.kind, NoticeKind.needed);
    expect(notice.seen, isFalse);
    expect(
      noticeFromData('g', 'n2', {'kind': 'bought'}).kind,
      NoticeKind.bought,
    );
  });

  test(
    'an update writes planning fields only when the planned state changes',
    () {
      const base = Product(
        id: 'p',
        groupId: 'g',
        name: 'Milk',
        position: 1,
        usage: 5,
      );
      final stays = productChange(
        base.copyWith(planned: true, plannedBy: 'a'),
        wasPlanned: true,
        me: 'a',
      );
      expect(stays.keys, ['name', 'position', 'planned']);

      final planned = productChange(
        base.copyWith(planned: true),
        wasPlanned: false,
        me: 'alice',
      );
      expect(planned['plannedBy'], 'alice');
      expect(planned.containsKey('plannedAt'), isTrue);

      final cleared = productChange(base, wasPlanned: true, me: 'a');
      expect(cleared.containsKey('plannedBy'), isTrue);
      expect(cleared['planned'], isFalse);

      final untouched = productChange(base, wasPlanned: false, me: 'a');
      expect(untouched.keys, ['name', 'position', 'planned']);
      expect(untouched.containsKey('usage'), isFalse);
    },
  );
}
