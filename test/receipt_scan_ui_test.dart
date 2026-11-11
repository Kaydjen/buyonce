import 'dart:convert';
import 'dart:typed_data';

import 'package:buyonce/core/utils/result.dart';
import 'package:buyonce/data/services/gemini_api.dart';
import 'package:buyonce/data/services/gemini_key_service.dart';
import 'package:buyonce/data/services/photo_service.dart';
import 'package:buyonce/data/services/receipt_camera.dart';
import 'package:buyonce/data/services/scripted_gemini_api.dart';
import 'package:buyonce/data/repositories/receipt_alias_repository.dart';
import 'package:buyonce/domain/models/receipt_matching.dart';
import 'package:buyonce/main.dart';
import 'package:buyonce/presentation/view_models/groups/groups_view_model.dart';

import 'receipt_fixtures.dart';

import 'package:buyonce/presentation/view_models/list/list_view_model.dart';
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
    {
      'raw': 'MLEKO',
      'kind': 'item',
      'evidence': 'MLEKO',
      'meaning': 'mleko = milk',
      'match': 'Milk',
      'confidence': 'high',
      'price': '10,00',
    },
    {'raw': 'KOMIN', 'kind': 'item', 'name': 'Komin', 'price': '25,00'},
  ],
});

/// What a test of the receipt flow holds on to.
class Rig {
  Rig(this.container, this.camera, this.gallery, this.api);
  final ProviderContainer container;
  final ScriptedReceiptCamera camera;
  final ScriptedPhotoService gallery;
  final ScriptedGeminiApi api;
}

/// Opens the app on Shop (its start screen) with a scripted camera, gallery and Gemini.
Future<Rig> openShop(
  WidgetTester tester, {
  Result<GeminiReply> Function(GeminiCall call)? script,
  List<Uint8List>? shots,
  List<List<Uint8List>> pickable = const [],
  CameraError? cameraError,
  bool galleryError = false,
  bool withKey = true,
}) async {
  if (withKey) await GeminiKeyService().write('key-1');
  final camera = ScriptedReceiptCamera(
    shots ?? [_jpeg, _jpeg, _jpeg, _jpeg],
    error: cameraError,
  );
  final gallery = ScriptedPhotoService(
    const [],
    gallery: pickable,
    error: galleryError,
  );
  final api = ScriptedGeminiApi(script ?? (c) => receiptReply(c, _answer));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        receiptCameraProvider.overrideWithValue(camera),
        photoServiceProvider.overrideWithValue(gallery),
        geminiApiProvider.overrideWithValue(api),
      ],
      child: const BuyOnceApp(),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  return Rig(container, camera, gallery, api);
}

Future<void> tapScan(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('scanReceipt')));
  await tester.pumpAndSettle();
}

Future<void> shoot(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('cameraShutter')));
  await tester.pumpAndSettle();
}

Future<void> readNow(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('cameraRead')));
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

  testWidgets(
    'the camera screen: preview, shutter, lamp, gallery at the bottom right',
    (tester) async {
      final rig = await openShop(tester);
      await tapScan(tester);
      expect(rig.camera.opened, 1);
      expect(
        rig.api.warmUps,
        1,
      ); // the connection is opened while the user aims
      expect(find.byKey(const Key('fakePreview')), findsOneWidget);
      expect(find.byKey(const Key('cameraShutter')), findsOneWidget);
      expect(find.byKey(const Key('cameraTorch')), findsOneWidget);
      // Nothing to read yet.
      expect(find.byKey(const Key('cameraRead')), findsNothing);
      // The gallery button is at the bottom right, the shutter in the middle.
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      final gallery = tester.getCenter(find.byKey(const Key('cameraGallery')));
      final shutter = tester.getCenter(find.byKey(const Key('cameraShutter')));
      expect(gallery.dx, greaterThan(size.width * 0.75));
      expect(gallery.dy, greaterThan(size.height * 0.7));
      expect((shutter.dx - size.width / 2).abs(), lessThan(8));
      // The lamp.
      await tester.tap(find.byKey(const Key('cameraTorch')));
      await tester.pumpAndSettle();
      expect(rig.camera.torch, isTrue);
    },
  );

  testWidgets('one shot: Read sends it and the review opens', (tester) async {
    final rig = await openShop(tester);
    await tapScan(tester);
    await shoot(tester);
    expect(rig.camera.taken, 1);
    expect(find.byKey(const ValueKey('thumb-0')), findsOneWidget);
    await readNow(tester);
    final parts =
        ((rig.api.calls.first.body['contents'] as List).single as Map)['parts']
            as List;
    expect(parts.length, 2); // prompt + one photo
    expect((parts[0] as Map)['text'], contains('Milk'));
    // The camera is gone, the review is on screen.
    expect(find.byKey(const Key('cameraShutter')), findsNothing);
    expect(find.byKey(const Key('boughtHeader')), findsOneWidget);
    expect(rig.camera.closed, isTrue);
    final review = rig.container.read(receiptReviewProvider)!;
    expect(review.store, 'Auchan');
    expect(review.fresh.single.name, 'Komin');
  });

  testWidgets('three shots read by themselves; a shot can be taken back', (
    tester,
  ) async {
    final rig = await openShop(tester);
    await tapScan(tester);
    await shoot(tester);
    await shoot(tester);
    expect(find.byKey(const ValueKey('thumb-1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('thumb-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('thumb-1')), findsNothing);
    await shoot(tester);
    await shoot(tester);
    // Three photos are the most: the reading started without a question.
    expect(rig.camera.taken, 4);
    final parts =
        ((rig.api.calls.first.body['contents'] as List).single as Map)['parts']
            as List;
    expect(parts.length, 4);
    expect(find.byKey(const Key('boughtHeader')), findsOneWidget);
  });

  testWidgets('the gallery: chosen photos join the shots, "Read" sends them', (
    tester,
  ) async {
    final rig = await openShop(
      tester,
      pickable: [
        [_jpeg, _jpeg],
      ],
    );
    await tapScan(tester);
    await shoot(tester);
    await tester.tap(find.byKey(const Key('cameraGallery')));
    await tester.pumpAndSettle();
    expect(rig.gallery.galleryOpened, 1);
    // One shot and two photos fill the three places: the reading started.
    final parts =
        ((rig.api.calls.first.body['contents'] as List).single as Map)['parts']
            as List;
    expect(parts.length, 4);
    expect(find.byKey(const Key('boughtHeader')), findsOneWidget);
  });

  testWidgets('a gallery pick that is not full waits for Read', (tester) async {
    final rig = await openShop(
      tester,
      pickable: [
        [_jpeg],
      ],
    );
    await tapScan(tester);
    await tester.tap(find.byKey(const Key('cameraGallery')));
    await tester.pumpAndSettle();
    expect(rig.api.calls, isEmpty);
    expect(find.byKey(const ValueKey('thumb-0')), findsOneWidget);
    await readNow(tester);
    expect(find.byKey(const Key('boughtHeader')), findsOneWidget);
  });

  testWidgets('closing the camera throws the shots away', (tester) async {
    final rig = await openShop(tester);
    await tapScan(tester);
    await shoot(tester);
    await tester.tap(find.byKey(const Key('cameraClose')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cameraShutter')), findsNothing);
    expect(rig.api.calls, isEmpty);
    expect(rig.container.read(receiptScanProvider).photos, 0);
    expect(rig.container.read(receiptScanProvider.notifier).photos, isEmpty);
  });

  testWidgets('no key: the key dialog first, no camera', (tester) async {
    final rig = await openShop(tester, withKey: false);
    await tapScan(tester);
    expect(find.byType(CardDialog), findsOneWidget);
    expect(rig.camera.opened, 0);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(rig.camera.opened, 0);
  });

  testWidgets('no access to the camera: told so, the gallery still works', (
    tester,
  ) async {
    final rig = await openShop(
      tester,
      cameraError: CameraError.denied,
      pickable: [
        [_jpeg],
      ],
    );
    await tapScan(tester);
    expect(find.text('No access to the camera'), findsOneWidget);
    expect(find.byKey(const Key('fakePreview')), findsNothing);
    // The shutter is off, the lamp is not offered, the gallery is.
    expect(find.byKey(const Key('cameraTorch')), findsNothing);
    await tester.tap(find.byKey(const Key('cameraShutter')));
    await tester.pumpAndSettle();
    expect(rig.camera.taken, 0);
    await tester.tap(find.byKey(const Key('cameraGallery')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('thumb-0')), findsOneWidget);
  });

  testWidgets('a camera that is not there is told the same way', (
    tester,
  ) async {
    await openShop(tester, cameraError: CameraError.unavailable);
    await tapScan(tester);
    expect(find.text('The camera is not available'), findsOneWidget);
  });

  testWidgets('a failure: a message with Retry that reads the same photos', (
    tester,
  ) async {
    var n = 0;
    final rig = await openShop(
      tester,
      script: (c) {
        if (isMatcherCall(c)) return receiptReply(c, _answer);
        return ++n == 1
            ? ScriptedGeminiApi.text('not json')
            : receiptReply(c, _answer);
      },
    );
    await tapScan(tester);
    await shoot(tester);
    await readNow(tester);
    expect(find.text("Couldn't read this receipt"), findsOneWidget);
    expect(
      find.byKey(const Key('cameraShutter')),
      findsOneWidget,
    ); // still here
    expect(rig.container.read(receiptReviewProvider), isNull);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(rig.camera.taken, 1); // no new shot
    expect(rig.api.calls.length, greaterThanOrEqualTo(2));
    expect(find.byKey(const Key('boughtHeader')), findsOneWidget);
  });

  testWidgets('a broken gallery is told the same way', (tester) async {
    await openShop(tester, galleryError: true);
    await tapScan(tester);
    await tester.tap(find.byKey(const Key('cameraGallery')));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't read this receipt"), findsOneWidget);
  });

  group('review screen', () {
    // The reader and the second reader disagree about the milk line.
    final disagree = jsonEncode({
      'matches': [
        {'index': 0, 'evidence': 'MLEKO', 'match': null},
      ],
    });

    Future<ProviderContainer> openReview(
      WidgetTester tester, {
      String? answer,
      String? matcher,
    }) async {
      final rig = await openShop(
        tester,
        script: (call) =>
            receiptReply(call, answer ?? _answer, matcher: matcher),
      );
      await tapScan(tester);
      await shoot(tester);
      await readNow(tester);
      return rig.container;
    }

    testWidgets('opens after reading: the list against the receipt', (
      tester,
    ) async {
      final c = await openReview(tester);
      expect(find.text('Auchan'), findsOneWidget);
      // Milk is one of the four planned products and is on the receipt.
      expect(find.text('Bought 1 of 4'), findsOneWidget);
      expect(find.byKey(const Key('inCard')), findsOneWidget);
      expect(find.byKey(const Key('checkCard')), findsNothing);
      expect(find.text('Milk'), findsWidgets);
      // The printed text is beside the match, to check it against.
      expect(find.byKey(const Key('printed-r0')), findsOneWidget);
      expect(find.text('MLEKO'), findsOneWidget);
      // What the list wanted and the receipt does not show.
      expect(find.byKey(const Key('missingCard')), findsOneWidget);
      expect(find.text('Salad'), findsOneWidget);
      // The other line is folded away and nothing is asked about it.
      expect(find.text('1 more receipt lines'), findsOneWidget);
      expect(find.text('Komin'), findsNothing);
      expect(find.text('Check off 1'), findsOneWidget);
      expect(c.read(receiptScanProvider).reviewReady, isFalse);
    });

    testWidgets(
      'Check off writes the mark, the trace, the receipt; learns the pair',
      (tester) async {
        final c = await openReview(tester);
        await tester.tap(find.byKey(const Key('markReceipt')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('markReceipt')), findsNothing);
        expect(find.text('Marked: 1'), findsOneWidget);
        final s = c.read(listViewModelProvider).requireValue;
        final milk = s.products.firstWhere((p) => p.name == 'Milk');
        expect(s.products.any((p) => p.name == 'Komin'), isFalse);
        final trip = s.trips.firstWhere((t) => t.userId == s.userId);
        expect(trip.marks.single.productId, milk.id);
        expect(trip.marks.single.receiptText, 'MLEKO');
        expect(trip.marks.single.price?.minor, 1000);
        expect(trip.receipts.single.store, 'Auchan');
        expect(c.read(receiptReviewProvider), isNull);
        // The photos are gone with the review.
        expect(c.read(receiptScanProvider.notifier).photos, isEmpty);
        final learned = await c
            .read(receiptAliasRepositoryProvider)
            .load(c.read(activeGroupIdProvider)!);
        expect(learned[printedKey('MLEKO')], milk.id);
      },
    );

    testWidgets('a line that is not on the list is added only when ticked', (
      tester,
    ) async {
      final c = await openReview(tester);
      await tester.tap(find.byKey(const Key('moreLines')));
      await tester.pumpAndSettle();
      expect(find.text('Komin'), findsOneWidget);
      await tester.tap(find.byKey(const Key('check-r1')));
      await tester.pumpAndSettle();
      expect(find.text('Check off 2'), findsOneWidget);
      await tester.tap(find.byKey(const Key('markReceipt')));
      await tester.pumpAndSettle();
      final s = c.read(listViewModelProvider).requireValue;
      final komin = s.products.firstWhere((p) => p.name == 'Komin');
      expect(komin.planned, isFalse);
      expect(s.myMarkIds, contains(komin.id));
    });

    testWidgets('back writes nothing and drops the review and the photos', (
      tester,
    ) async {
      final c = await openReview(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('inCard')), findsNothing);
      expect(c.read(receiptReviewProvider), isNull);
      expect(c.read(receiptScanProvider.notifier).photos, isEmpty);
      final s = c.read(listViewModelProvider).requireValue;
      expect(s.products.any((p) => p.name == 'Komin'), isFalse);
      expect(s.trips.where((t) => t.userId == s.userId), isEmpty);
    });

    testWidgets(
      'a doubtful match is shown first, unticked, with the printed text and its reading',
      (tester) async {
        final c = await openReview(tester, matcher: disagree);
        expect(find.byKey(const Key('checkCard')), findsOneWidget);
        expect(find.byKey(const Key('inCard')), findsNothing);
        // The card says what to do, the row is a question until it is ticked.
        expect(find.text('Check the name'), findsOneWidget);
        expect(find.text('Milk?'), findsOneWidget);
        expect(find.byKey(const Key('printed-r0')), findsOneWidget);
        expect(find.text('mleko = milk'), findsOneWidget);
        // Nothing is ticked, so the button is on screen but off.
        expect(find.text('Check off 0'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('markReceipt')))
              .onPressed,
          isNull,
        );
        expect(find.text('Bought 0 of 4'), findsOneWidget);
        // The user looks at it and agrees.
        await tester.tap(find.byKey(const Key('check-r0')));
        await tester.pumpAndSettle();
        expect(find.text('Check off 1'), findsOneWidget);
        expect(find.text('Milk?'), findsNothing);
        expect(find.text('Milk'), findsWidgets);
        expect(find.text('Bought 1 of 4'), findsOneWidget);
        expect(c.read(receiptReviewProvider)!.chosen.single.name, 'Milk');
      },
    );

    testWidgets('a wrong match: pick another product, or "None of these"', (
      tester,
    ) async {
      final c = await openReview(tester, matcher: disagree);
      await tester.tap(find.byKey(const Key('name-r0')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('pickerSearch')), 'bread');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bread'));
      await tester.pumpAndSettle();
      var row = c.read(receiptReviewProvider)!.found.single;
      expect(row.name, 'Bread');
      expect(row.checked, isTrue); // chosen by hand: a decision
      expect(find.byKey(const Key('checkCard')), findsNothing);

      await tester.tap(find.byKey(const Key('name-r0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pickNone')));
      await tester.pumpAndSettle();
      final review = c.read(receiptReviewProvider)!;
      expect(review.found, isEmpty);
      expect(review.fresh.map((r) => r.name), contains('MLEKO'));
      expect(review.fresh.every((r) => !r.checked), isTrue);
      expect(find.text('2 more receipt lines'), findsOneWidget);
    });

    testWidgets(
      'a product the receipt does not show can be pointed at a line',
      (tester) async {
        final c = await openReview(tester);
        // "Salad" is wanted, the receipt shows no salad; the spare line is its.
        await tester.tap(find.byKey(const ValueKey('missing-seed4')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('link-r1')));
        await tester.pumpAndSettle();
        final review = c.read(receiptReviewProvider)!;
        expect(review.confirmed.map((r) => r.name), contains('Salad'));
        expect(review.fresh, isEmpty);
        expect(find.byKey(const ValueKey('missing-seed4')), findsNothing);
        expect(find.text('Bought 2 of 4'), findsOneWidget);
      },
    );

    testWidgets('the photos of the receipt open for checking', (tester) async {
      await openReview(tester);
      await tester.tap(find.byKey(const Key('viewReceipt')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('receiptPhotos')), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('inCard')), findsOneWidget);
    });

    testWidgets(
      'a spare line is renamed in place; a catalog name moves it up',
      (tester) async {
        final c = await openReview(tester);
        await tester.tap(find.byKey(const Key('moreLines')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('name-r1')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Eggs');
        await tester.tap(find.widgetWithText(TextButton, 'Save'));
        await tester.pumpAndSettle();
        final review = c.read(receiptReviewProvider)!;
        expect(review.fresh, isEmpty);
        expect(review.confirmed.map((r) => r.name), ['Milk', 'Eggs']);
        expect(find.text('Check off 2'), findsOneWidget);
      },
    );
  });
}
