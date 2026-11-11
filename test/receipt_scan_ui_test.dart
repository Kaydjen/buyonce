import 'dart:convert';
import 'dart:typed_data';

import 'package:buyonce/core/utils/result.dart';
import 'package:buyonce/data/services/gemini_api.dart';
import 'package:buyonce/data/services/gemini_key_service.dart';
import 'package:buyonce/data/services/photo_service.dart';
import 'package:buyonce/data/services/scripted_gemini_api.dart';
import 'package:buyonce/main.dart';
import 'package:buyonce/presentation/view_models/receipt/receipt_review_view_model.dart';
import 'package:buyonce/presentation/view_models/receipt/receipt_scan_view_model.dart';
import 'package:buyonce/presentation/widgets/card_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _jpeg = Uint8List.fromList([9, 8, 7]);

final _answer = jsonEncode({
  'store': 'Auchan',
  'currency': 'PLN',
  'total': '35,00',
  'lines': [
    {'raw': 'MLEKO', 'kind': 'item', 'match': 'Milk', 'price': '10,00'},
    {'raw': 'KOMIN', 'kind': 'item', 'name': 'Komin', 'price': '25,00'},
  ],
});

/// Opens the app on Shop (its start screen) with a scripted camera and Gemini.
Future<(ProviderContainer, ScriptedPhotoService, ScriptedGeminiApi)> openShop(
  WidgetTester tester, {
  Result<GeminiReply> Function(GeminiCall call)? script,
  List<Uint8List?>? photos,
  bool photoError = false,
  bool withKey = true,
}) async {
  if (withKey) await GeminiKeyService().write('key-1');
  final camera = ScriptedPhotoService(
    photos ?? [_jpeg, _jpeg, _jpeg, _jpeg],
    error: photoError,
  );
  final api = ScriptedGeminiApi(
    script ?? (_) => ScriptedGeminiApi.text(_answer),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        photoServiceProvider.overrideWithValue(camera),
        geminiApiProvider.overrideWithValue(api),
      ],
      child: const BuyOnceApp(),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  return (container, camera, api);
}

Future<void> tapScan(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('scanReceipt')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the scan icon is in Shop, not in Plan', (tester) async {
    await openShop(tester);
    expect(find.byKey(const Key('scanReceipt')), findsOneWidget);
    expect(find.byKey(const Key('addProducts')), findsNothing);
    await tester.tap(find.byKey(const Key('tabPlan')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scanReceipt')), findsNothing);
    expect(find.byKey(const Key('addProducts')), findsOneWidget);
    await tester.tap(find.byKey(const Key('tabShop')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scanReceipt')), findsOneWidget);
  });

  testWidgets('one photo: Read sends it and the review is ready', (
    tester,
  ) async {
    final (c, camera, api) = await openShop(tester);
    await tapScan(tester);
    expect(camera.taken, 1);
    expect(api.warmUps, 1);
    expect(find.byType(CardDialog), findsOneWidget);
    expect(find.text('Photos: 1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('receiptRead')));
    await tester.pumpAndSettle();
    final parts =
        ((api.calls.single.body['contents'] as List).single as Map)['parts']
            as List;
    expect(parts.length, 2); // prompt + one photo
    expect((parts[0] as Map)['text'], contains('Milk; Bread'));
    expect(c.read(receiptScanProvider).reviewReady, isTrue);
    final review = c.read(receiptReviewProvider)!;
    expect(review.store, 'Auchan');
    expect(review.fresh.single.name, 'Komin');
  });

  testWidgets('Add photo opens the camera again; three photos read at once', (
    tester,
  ) async {
    final (c, camera, api) = await openShop(tester);
    await tapScan(tester);
    await tester.tap(find.byKey(const Key('receiptMore')));
    await tester.pumpAndSettle();
    expect(camera.taken, 2);
    expect(find.text('Photos: 2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('receiptMore')));
    await tester.pumpAndSettle();
    // The third shot is the last: no question, the reading starts.
    expect(camera.taken, 3);
    expect(find.byType(CardDialog), findsNothing);
    final parts =
        ((api.calls.single.body['contents'] as List).single as Map)['parts']
            as List;
    expect(parts.length, 4);
    expect(c.read(receiptScanProvider).reviewReady, isTrue);
  });

  testWidgets('closing the dialog throws the photo away', (tester) async {
    final (c, _, api) = await openShop(tester);
    await tapScan(tester);
    await tester.tapAt(const Offset(5, 5)); // the veil
    await tester.pumpAndSettle();
    expect(find.byType(CardDialog), findsNothing);
    expect(api.calls, isEmpty);
    expect(c.read(receiptScanProvider).photos, 0);
  });

  testWidgets('a closed camera does nothing', (tester) async {
    final (_, camera, api) = await openShop(tester, photos: [null]);
    await tapScan(tester);
    expect(camera.taken, 1);
    expect(find.byType(CardDialog), findsNothing);
    expect(api.calls, isEmpty);
  });

  testWidgets('no key: the key dialog first, no camera', (tester) async {
    final (_, camera, _) = await openShop(tester, withKey: false);
    await tapScan(tester);
    expect(find.byType(CardDialog), findsOneWidget);
    expect(camera.taken, 0);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(camera.taken, 0);
  });

  testWidgets('a failure: a message with Retry that reads the same photo', (
    tester,
  ) async {
    var n = 0;
    final (c, camera, api) = await openShop(
      tester,
      script: (_) => ++n == 1
          ? ScriptedGeminiApi.text('not json')
          : ScriptedGeminiApi.text(_answer),
    );
    await tapScan(tester);
    await tester.tap(find.byKey(const Key('receiptRead')));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't read this receipt"), findsOneWidget);
    expect(c.read(receiptReviewProvider), isNull);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(camera.taken, 1); // no new shot
    expect(api.calls.length, greaterThanOrEqualTo(2));
    expect(c.read(receiptScanProvider).reviewReady, isTrue);
  });

  testWidgets('a broken camera is told the same way', (tester) async {
    await openShop(tester, photoError: true);
    await tapScan(tester);
    expect(find.text("Couldn't read this receipt"), findsOneWidget);
    expect(find.byType(CardDialog), findsNothing);
  });
}
