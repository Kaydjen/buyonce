import 'package:buyonce/core/utils/result.dart';
import 'package:buyonce/data/services/in_memory_list_service.dart';
import 'package:buyonce/domain/models/notice.dart';
import 'package:buyonce/domain/models/product.dart';
import 'package:buyonce/presentation/widgets/notice_banner.dart';
import 'package:flutter_test/flutter_test.dart';

import 'list_repository_test.dart' show newRepo;

Product _p(String id, String name) =>
    Product(id: id, groupId: 'g', name: name, position: 0);

Notice _n(
  String id,
  String from,
  List<String> products, {
  NoticeKind kind = NoticeKind.bought,
  int minute = 0,
}) => Notice(
  id: id,
  groupId: 'g',
  toUserId: 'me',
  fromUserId: from,
  productIds: products,
  sentAt: DateTime(2026, 11, 3, 12, minute),
  kind: kind,
);

String _name(String id) => id == 'a' ? 'Anna' : 'Alex';

void main() {
  final products = [
    for (final n in ['Milk', 'Bread', 'Eggs', 'Tea', 'Jam']) _p(n, n),
  ];

  test('notices of one sender and kind become one line, oldest first', () {
    final lines = noticeLines(
      [
        _n('2', 'a', ['Eggs', 'Milk'], minute: 5),
        _n('1', 'a', ['Milk', 'Bread'], minute: 1),
      ],
      products,
      _name,
    );
    expect(lines, ['Anna bought: Milk, Bread, Eggs']);
  });

  test('another sender or kind gets its own line', () {
    final lines = noticeLines(
      [
        _n('1', 'a', ['Milk']),
        _n('2', 'a', ['Bread'], kind: NoticeKind.needed),
        _n('3', 'x', ['Eggs']),
      ],
      products,
      _name,
    );
    expect(lines, [
      'Anna bought: Milk',
      'Anna needs: Bread',
      'Alex bought: Eggs',
    ]);
  });

  test('more than three products end with +N', () {
    final lines = noticeLines(
      [
        _n('1', 'a', ['Milk', 'Bread', 'Eggs', 'Tea', 'Jam']),
      ],
      products,
      _name,
    );
    expect(lines, ['Anna bought: Milk, Bread, Eggs +2']);
  });

  test('a deleted product is left out, a line with none disappears', () {
    expect(
      noticeLines(
        [
          _n('1', 'a', ['Milk', 'Gone']),
        ],
        products,
        _name,
      ),
      ['Anna bought: Milk'],
    );
    expect(
      noticeLines(
        [
          _n('1', 'a', ['Gone']),
        ],
        products,
        _name,
      ),
      isEmpty,
    );
  });

  test('markNoticesSeen with sentBefore keeps the newer notices', () async {
    final service = InMemoryListService();
    final repo = newRepo(service);
    await repo.toggleMark('seed0', 'partner');
    await repo.sendStaleTrips(now: DateTime.now().add(const Duration(days: 2)));
    Future<int> unseen() async =>
        ((await repo.getNotices('me')) as Ok<List<Notice>>).value.length;
    expect(await unseen(), 1);

    await repo.markNoticesSeen(
      'me',
      sentBefore: DateTime.now().subtract(const Duration(hours: 1)),
    );
    expect(await unseen(), 1); // sent just now: stays

    await repo.markNoticesSeen(
      'me',
      sentBefore: DateTime.now().add(const Duration(minutes: 1)),
    );
    expect(await unseen(), 0);
  });
}
