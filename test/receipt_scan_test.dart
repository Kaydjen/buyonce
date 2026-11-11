import 'dart:convert';
import 'dart:typed_data';

import 'package:buyonce/data/services/gemini_api.dart';
import 'package:buyonce/data/services/gemini_key_service.dart';
import 'package:buyonce/data/services/photo_service.dart';
import 'package:buyonce/data/services/scripted_gemini_api.dart';
import 'package:buyonce/domain/models/gemini_outcome.dart';
import 'package:buyonce/domain/models/product.dart';
import 'package:buyonce/presentation/view_models/list/list_state.dart';
import 'package:buyonce/presentation/view_models/list/list_view_model.dart';
import 'package:buyonce/presentation/view_models/receipt/receipt_review_view_model.dart';
import 'package:buyonce/presentation/view_models/receipt/receipt_scan_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'receipt_fixtures.dart';

final _jpeg = Uint8List.fromList([1, 2, 3]);

const _answer = {
  'store': 'Auchan',
  'currency': 'PLN',
  'total': '35,00',
  'lines': [
    {'raw': 'MLEKO', 'kind': 'item', 'match': 'Milk', 'price': '10,00'},
    {'raw': 'KOMIN', 'kind': 'item', 'name': 'Komin', 'price': '25,00'},
  ],
};

class _FakeList extends ListViewModel {
  @override
  Future<ListState> build() async => const ListState(
    products: [Product(id: 'milk', groupId: 'g', name: 'Milk', position: 1)],
  );
}

Future<(ProviderContainer, ScriptedPhotoService, ScriptedGeminiApi)> _rig({
  List<Uint8List?>? photos,
  bool photoError = false,
  Object? Function(GeminiCall)? script,
  bool withKey = true,
}) async {
  if (withKey) await GeminiKeyService().write('key-1');
  final camera = ScriptedPhotoService(
    photos ?? [_jpeg, _jpeg, _jpeg, _jpeg],
    error: photoError,
  );
  final api = ScriptedGeminiApi(
    (c) => receiptReply(c, jsonEncode(script?.call(c) ?? _answer)),
  );
  final container = ProviderContainer(
    overrides: [
      photoServiceProvider.overrideWithValue(camera),
      geminiApiProvider.overrideWithValue(api),
      listViewModelProvider.overrideWith(_FakeList.new),
    ],
  );
  addTearDown(container.dispose);
  await container.read(listViewModelProvider.future);
  return (container, camera, api);
}

Future<void> _read(ProviderContainer c) => c
    .read(receiptScanProvider.notifier)
    .read(language: 'English', fallbackCurrency: 'PLN');

void main() {
  test('photos are counted, at most three; reading opens the review', () async {
    final (c, camera, api) = await _rig();
    final vm = c.read(receiptScanProvider.notifier);
    expect(c.read(receiptScanProvider).photos, 0);
    expect(await vm.addPhoto(), isTrue);
    expect(await vm.addPhoto(), isTrue);
    expect(await vm.addPhoto(), isTrue);
    expect(c.read(receiptScanProvider).canAddPhoto, isFalse);
    expect(await vm.addPhoto(), isFalse); // the limit: the camera is not opened
    expect(camera.taken, 3);

    await _read(c);
    final scan = c.read(receiptScanProvider);
    expect(scan.reviewReady, isTrue);
    expect(scan.photos, 3); // kept in memory for the review to show
    expect(scan.problem, isNull);
    final parts =
        ((api.calls.first.body['contents'] as List).single as Map)['parts']
            as List;
    expect(parts.length, 4); // prompt + 3 photos
    final review = c.read(receiptReviewProvider)!;
    expect(review.found.single.product!.name, 'Milk');
    expect(review.fresh.single.name, 'Komin');

    vm.reviewShown();
    expect(c.read(receiptScanProvider).reviewReady, isFalse);
  });

  test(
    'a closed camera adds nothing, a broken one reports a problem',
    () async {
      final (c, _, _) = await _rig(photos: [null]);
      final vm = c.read(receiptScanProvider.notifier);
      expect(await vm.addPhoto(), isFalse);
      expect(c.read(receiptScanProvider).photos, 0);
      expect(c.read(receiptScanProvider).problem, isNull);

      final (c2, _, _) = await _rig(photoError: true);
      expect(await c2.read(receiptScanProvider.notifier).addPhoto(), isFalse);
      expect(c2.read(receiptScanProvider).problem, isA<GeminiFailed>());
      c2.read(receiptScanProvider.notifier).problemShown();
      expect(c2.read(receiptScanProvider).problem, isNull);
    },
  );

  test('reading without photos does nothing', () async {
    final (c, _, api) = await _rig();
    await _read(c);
    expect(api.calls, isEmpty);
    expect(c.read(receiptReviewProvider), isNull);
  });

  test('a problem keeps the photos for a retry and opens no review', () async {
    final (c, _, _) = await _rig(withKey: false);
    final vm = c.read(receiptScanProvider.notifier);
    await vm.addPhoto();
    await _read(c);
    var scan = c.read(receiptScanProvider);
    expect(scan.problem, isA<GeminiNoKey>());
    expect(scan.photos, 1);
    expect(scan.busy, isFalse);
    expect(c.read(receiptReviewProvider), isNull);

    await GeminiKeyService().write('key-1');
    vm.problemShown();
    await _read(c); // the retry uses the same photo, no new shot
    scan = c.read(receiptScanProvider);
    expect(scan.reviewReady, isTrue);
  });

  test('reset drops the photos', () async {
    final (c, _, _) = await _rig();
    final vm = c.read(receiptScanProvider.notifier);
    await vm.addPhoto();
    expect(c.read(receiptScanProvider).photos, 1);
    vm.reset();
    expect(c.read(receiptScanProvider).photos, 0);
  });

  test(
    'the model is told what is wanted now first, then what is bought most',
    () {
      const list = ListState(
        products: [
          Product(id: 'a', groupId: 'g', name: 'Rare', position: 1),
          Product(id: 'b', groupId: 'g', name: 'Often', position: 2, usage: 9),
          Product(
            id: 'c',
            groupId: 'g',
            name: 'Wanted',
            position: 3,
            planned: true,
          ),
          Product(
            id: 'd',
            groupId: 'g',
            name: 'Sometimes',
            position: 4,
            usage: 3,
          ),
        ],
      );
      expect(ReceiptScanViewModel.namesByImportance(list), [
        'Wanted',
        'Often',
        'Sometimes',
        'Rare',
      ]);
    },
  );
}
