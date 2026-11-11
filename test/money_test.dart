import 'dart:convert';

import 'package:buyonce/data/services/firebase_list_service.dart';
import 'package:buyonce/data/services/in_memory_list_service.dart';
import 'package:buyonce/data/services/list_snapshot.dart';
import 'package:buyonce/data/services/money_codec.dart';
import 'package:buyonce/domain/models/amount.dart';
import 'package:buyonce/domain/models/money.dart';
import 'package:buyonce/domain/models/receipt.dart';
import 'package:buyonce/domain/models/trip.dart';
import 'package:buyonce/domain/models/trip_mark.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Money? _uah(String s) => parseMoney(s, 'UAH');

void main() {
  final t0 = DateTime.utc(2026, 11, 1, 10);

  group('parseMoney', () {
    test('plain, decimal comma and point', () {
      expect(_uah('32,90'), const Money(3290, 'UAH'));
      expect(_uah('32.90'), const Money(3290, 'UAH'));
      expect(_uah('32'), const Money(3200, 'UAH'));
      expect(_uah('0,5'), const Money(50, 'UAH'));
      expect(_uah('.5'), const Money(50, 'UAH'));
      expect(_uah('0'), const Money(0, 'UAH'));
    });

    test('grouping of thousands', () {
      expect(_uah('1 234.50'), const Money(123450, 'UAH'));
      expect(_uah('1 234,50'), const Money(123450, 'UAH'));
      expect(_uah('1.234,50'), const Money(123450, 'UAH'));
      expect(_uah('1,234.50'), const Money(123450, 'UAH'));
      expect(_uah('1,234,567'), const Money(123456700, 'UAH'));
      // Exactly three digits after a lone separator: grouping when the currency has 2.
      expect(_uah('1,234'), const Money(123400, 'UAH'));
      expect(_uah('1.5'), const Money(150, 'UAH'));
    });

    test('currencies with other digits', () {
      expect(parseMoney('1234', 'JPY'), const Money(1234, 'JPY'));
      expect(parseMoney('1,234', 'KWD'), const Money(1234, 'KWD'));
      expect(parseMoney('12.5', 'pln'), const Money(1250, 'PLN'));
      // More decimals than the currency has.
      expect(parseMoney('12.50', 'JPY'), isNull);
    });

    test('negative values and rubbish', () {
      expect(_uah('-5,00'), const Money(-500, 'UAH'));
      expect(_uah('−5,00'), const Money(-500, 'UAH'));
      for (final bad in [
        '',
        ' ',
        'abc',
        '1,2,3,4x',
        '12,345,67',
        '1.234.5',
        ',',
        '1,234,56',
        '1,23456',
      ]) {
        expect(_uah(bad), isNull, reason: bad);
      }
    });
  });

  group('sumMoney', () {
    test('a missing price is counted, never added as 0', () {
      final s = sumMoney([
        const Money(100, 'UAH'),
        null,
        const Money(250, 'UAH'),
        null,
      ]);
      expect(s.totals, {'UAH': 350});
      expect(s.missing, 2);
      expect(s.complete, isFalse);
      expect(s.single, const Money(350, 'UAH'));
    });

    test('currencies never mix, zero is a real price', () {
      final s = sumMoney([const Money(0, 'UAH'), const Money(5, 'EUR')]);
      expect(s.totals, {'UAH': 0, 'EUR': 5});
      expect(s.complete, isTrue);
      expect(s.single, isNull);
    });

    test('nothing at all is an empty, complete sum', () {
      final s = sumMoney(const []);
      expect(s.totals, isEmpty);
      expect(s.complete, isTrue);
      expect(s.single, isNull);
    });
  });

  group('codec', () {
    test('money round-trips; damaged data is no price', () {
      const m = Money(3290, 'UAH');
      expect(moneyFromData(moneyToData(m)), m);
      expect(moneyFromData(null), isNull);
      expect(moneyFromData('x'), isNull);
      expect(moneyFromData({'minor': 1.5, 'cur': 'UAH'}), isNull);
      expect(moneyFromData({'minor': 5, 'cur': 'uah'}), isNull);
      expect(moneyFromData({'minor': 5}), isNull);
      expect(moneyFromData({'cur': 'UAH'}), isNull);
    });
  });

  group('Firestore mapping', () {
    final receipt = Receipt(
      store: 'Shop',
      date: t0,
      total: const Money(5000, 'UAH'),
      discount: const Money(300, 'UAH'),
    );

    test('marks with and without price keep both; a price of 0 stays', () {
      final data = marksToData([
        TripMark(
          productId: 'a',
          userId: 'bob',
          markedAt: t0,
          amount: const Amount(count: 2),
          price: const Money(3290, 'UAH'),
          discount: const Money(100, 'UAH'),
        ),
        TripMark(
          productId: 'free',
          userId: 'bob',
          markedAt: t0,
          price: const Money(0, 'UAH'),
        ),
        TripMark(productId: 'plain', userId: 'bob', markedAt: t0),
      ]);
      // Nothing known: the bare time, as before.
      expect(data['plain'], isA<Timestamp>());
      expect((data['a']! as Map).containsKey('price'), isTrue);
      final trip = tripFromData('g', 't', {
        'userId': 'bob',
        'startedAt': Timestamp.fromDate(t0),
        'marks': data,
      });
      TripMark by(String id) => trip.marks.firstWhere((m) => m.productId == id);
      expect(by('a').price, const Money(3290, 'UAH'));
      expect(by('a').discount, const Money(100, 'UAH'));
      expect(by('a').amount, const Amount(count: 2));
      expect(by('free').price, const Money(0, 'UAH'));
      expect(by('free').discount, isNull);
      expect(by('plain').price, isNull);
      expect(by('plain').discount, isNull);
    });

    test('receipts round-trip; a damaged entry is skipped', () {
      final back = receiptsFromData(receiptsToData([receipt, const Receipt()]));
      expect(back.length, 2);
      expect(back[0].store, 'Shop');
      expect(back[0].date!.isAtSameMomentAs(t0), isTrue);
      expect(back[0].total, receipt.total);
      expect(back[0].discount, receipt.discount);
      expect(back[1].store, isNull);
      expect(back[1].total, isNull);
      expect(receiptsFromData(null), isEmpty);
      expect(receiptsFromData([5, 'x', {'total': 'bad'}]).single.total, isNull);
      final trip = tripFromData('g', 't', {
        'userId': 'bob',
        'startedAt': Timestamp.fromDate(t0),
        'marks': <String, Object?>{},
        'receipts': receiptsToData([receipt]),
      });
      expect(trip.receipts.single.total, receipt.total);
      expect(
        tripFromData('g', 't', {
          'userId': 'bob',
          'startedAt': Timestamp.fromDate(t0),
          'marks': <String, Object?>{},
        }).receipts,
        isEmpty,
      );
    });
  });

  test('the local snapshot keeps prices, discounts and receipts', () async {
    final service = InMemoryListService(seed: false);
    await service.createTrip(
      Trip(
        id: 't',
        groupId: 'personal-me',
        userId: 'me',
        startedAt: t0,
        marks: [
          TripMark(
            productId: 'a',
            userId: 'me',
            markedAt: t0,
            price: const Money(3290, 'UAH'),
            discount: const Money(100, 'UAH'),
          ),
          TripMark(productId: 'b', userId: 'me', markedAt: t0),
        ],
        receipts: [
          Receipt(store: 'Shop', date: t0, total: const Money(5000, 'UAH')),
        ],
      ),
    );
    final json = jsonDecode(
      jsonEncode(service.snapshotOf('personal-me').toJson()),
    );
    final trip = ListSnapshot.tryParse(json)!.trips.single;
    final a = trip.marks.firstWhere((m) => m.productId == 'a');
    final b = trip.marks.firstWhere((m) => m.productId == 'b');
    expect(a.price, const Money(3290, 'UAH'));
    expect(a.discount, const Money(100, 'UAH'));
    expect(b.price, isNull);
    expect(trip.receipts.single.store, 'Shop');
    expect(trip.receipts.single.total, const Money(5000, 'UAH'));
  });

  test('a mark copy keeps the price unless it is cleared', () {
    final m = TripMark(
      productId: 'a',
      userId: 'me',
      markedAt: t0,
      price: const Money(100, 'UAH'),
    );
    expect(
      m.copyWith(amount: const Amount(count: 3)).price,
      const Money(100, 'UAH'),
    );
    expect(m.copyWith(clearPrice: true).price, isNull);
  });
}
