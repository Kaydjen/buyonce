import 'package:buyonce/data/services/firebase_group_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime.utc(2026, 11, 1);
  MemberData member(String id, {bool muted = false, int day = 1}) =>
      (userId: id, muted: muted, joinedAt: t0.add(Duration(days: day)));

  test('a group document and its members make a Group', () {
    final group = groupFromData(
      'g1',
      {
        'name': 'Home',
        'utcOffsetMin': 180,
        'ownerId': 'alice',
        'personal': false,
        'inviteCode': 'ABCD2345',
        'memberCount': 2,
      },
      [member('bob', muted: true, day: 3), member('alice', day: 1)],
    )!;
    expect(group.name, 'Home');
    expect(group.utcOffset, const Duration(hours: 3));
    expect(group.ownerId, 'alice');
    expect(group.memberIds, ['alice', 'bob']);
    expect(group.mutedUserIds, {'bob'});
    expect(group.inviteCode, 'ABCD2345');
    expect(group.personal, isFalse);
  });

  test('a personal list has no code; a missing document is no group', () {
    final personal = groupFromData(
      'personal-me',
      {
        'name': 'Personal',
        'utcOffsetMin': -300,
        'ownerId': 'me',
        'personal': true,
      },
      [member('me')],
    )!;
    expect(personal.inviteCode, isEmpty);
    expect(personal.personal, isTrue);
    expect(personal.utcOffset, const Duration(hours: -5));
    expect(groupFromData('x', null, const []), isNull);
  });

  test('a server time that is not back yet counts as now', () {
    final before = DateTime.now();
    expect(timeOf(null).isBefore(before), isFalse);
    expect(timeOf(Timestamp.fromDate(t0)).isAtSameMomentAs(t0), isTrue);
    expect(
      memberFromData({'userId': 'a', 'muted': true, 'joinedAt': null}).muted,
      isTrue,
    );
  });
}
