import 'package:buyonce/core/theme/style_variant.dart';
import 'package:buyonce/main.dart';
import 'package:buyonce/presentation/view_models/settings/style_variant_view_model.dart';
import 'package:buyonce/presentation/widgets/edge_fade.dart';
import 'package:buyonce/presentation/widgets/titled_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, StyleVariant variant) async {
  // The size of the owner's phone (411 x 914 dp), cut short so the Plan list scrolls.
  tester.view.physicalSize = const Size(1080, 1600);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: BuyOnceApp()));
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  container.read(styleVariantProvider.notifier).select(variant);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('tabPlan')));
  await tester.pumpAndSettle();
}

Finder get _list => find.byType(Scrollable).first;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final variant in [StyleVariant.d1, StyleVariant.d7]) {
    group(variant.name, () {
      testWidgets('a tab switch puts the icon in place without a flight', (
        tester,
      ) async {
        await _pump(tester, variant);
        await tester.drag(_list, const Offset(0, -700));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('findDock')), findsOneWidget);

        Finder icon() => find.byKey(const Key('findDock')).evaluate().isNotEmpty
            ? find.byKey(const Key('findDock'))
            : find.byKey(const Key('findButton'));
        for (final tab in ['tabShop', 'tabPlan']) {
          await tester.tap(find.byKey(Key(tab)));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 32));
          final early = tester.getCenter(icon());
          await tester.pumpAndSettle();
          expect(tester.getCenter(icon()), early, reason: tab);
        }
      });

      testWidgets('the icon docks when the Select title scrolls away', (
        tester,
      ) async {
        await _pump(tester, variant);
        expect(find.byKey(const Key('findDock')), findsNothing);
        expect(find.byKey(const Key('findButton')), findsOneWidget);

        await tester.drag(_list, const Offset(0, -700));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('findDock')), findsOneWidget);

        await tester.drag(_list, const Offset(0, 2000));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('findDock')), findsNothing);
        expect(find.byKey(const Key('findButton')), findsOneWidget);
      });

      testWidgets('the icon glides from the card to the bar with the scroll', (
        tester,
      ) async {
        await _pump(tester, variant);
        final position = tester.state<ScrollableState>(_list).position;
        final home = tester.getCenter(find.byKey(const Key('findButton'))).dx;
        // Soft plates are 52 dp wide, the flat icon buttons 48.
        final plateWidth = variant == StyleVariant.d7 ? 52 : 48;
        final slot =
            tester.getCenter(find.byKey(const Key('addProducts'))).dx -
            plateWidth;

        // The card button is still cut by the top of the list: no overlay.
        position.jumpTo(5);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('findDock')), findsNothing);

        // Just past the point where the button leaves the card, the scroll stops: the
        // icon still glides all the way to the slot, on its own.
        position.jumpTo(75);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final middle = tester.getCenter(find.byKey(const Key('findDock'))).dx;
        expect(middle, lessThan(home - 5));
        expect(middle, greaterThan(slot + 5));
        await tester.pumpAndSettle();
        expect(
          tester.getCenter(find.byKey(const Key('findDock'))).dx,
          // The flat design lays its bar out a little differently.
          closeTo(slot, variant == StyleVariant.d7 ? 1 : 12),
        );

        // Back close to the top: the icon returns to the card and the overlay is gone.
        position.jumpTo(10);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('findDock')), findsNothing);
        expect(find.byKey(const Key('findButton')), findsOneWidget);
      });

      testWidgets('a fast scroll never sends the icon off the screen', (
        tester,
      ) async {
        await _pump(tester, variant);
        final position = tester.state<ScrollableState>(_list).position;
        final height =
            tester.view.physicalSize.height / tester.view.devicePixelRatio;

        position.jumpTo(1000);
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          final dock = find.byKey(const Key('findDock'));
          if (dock.evaluate().isEmpty) continue;
          final y = tester.getCenter(dock).dy;
          expect(y, inInclusiveRange(0, height), reason: 'frame $i');
        }
      });

      testWidgets('the bar paints over the list and the list starts below it', (
        tester,
      ) async {
        await _pump(tester, variant);
        final layout = tester.widget<CustomMultiChildLayout>(
          find.byWidgetPredicate(
            (w) =>
                w is CustomMultiChildLayout &&
                w.delegate.runtimeType.toString() == '_TopOverListLayout',
          ),
        );
        // The last child paints last: the bar group, not the list.
        final ids = [for (final c in layout.children) (c as LayoutId).id];
        expect(ids.last.toString(), contains('top'));

        final bar = tester.getRect(find.byKey(const Key('groupButton')));
        final list = tester.getTopLeft(find.byType(EdgeFade).first);
        expect(list.dy, greaterThanOrEqualTo(bar.bottom));
      });

      testWidgets('the top fade of the list grows with the scroll', (
        tester,
      ) async {
        await _pump(tester, variant);
        double fade() => tester
            .widget<Opacity>(
              find
                  .descendant(
                    of: find.byType(EdgeFade),
                    matching: find.byType(Opacity),
                  )
                  .last,
            )
            .opacity;
        expect(fade(), 0);
        await tester.drag(_list, const Offset(0, -700));
        await tester.pumpAndSettle();
        expect(fade(), 1);
      });

      testWidgets('a tap on the dock scrolls to the card and opens the field', (
        tester,
      ) async {
        await _pump(tester, variant);
        await tester.drag(_list, const Offset(0, -700));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('addField')), findsNothing);

        await tester.tap(find.byKey(const Key('findDock')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('addField')), findsOneWidget);
        expect(find.byKey(const Key('findDock')), findsNothing);

        // The field is open: scroll away and tap again, it only comes back and focuses.
        await tester.drag(_list, const Offset(0, -700));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('findDock')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('addField')), findsOneWidget);
        final field = tester.widget<TextField>(
          find.byKey(const Key('addField')),
        );
        expect(field.focusNode!.hasFocus, isTrue);
      });
    });
  }

  testWidgets('the first card of Settings leaves room for its soft shadow', (
    tester,
  ) async {
    await _pump(tester, StyleVariant.d7);
    await tester.tap(find.byKey(const Key('menuButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    // The light shadow reaches about 2.5 times the depth (8) above a card.
    final gap =
        tester.getTopLeft(find.byType(TitledCard).first).dy -
        tester.getBottomLeft(find.byType(AppBar)).dy;
    expect(gap, greaterThanOrEqualTo(24));
  });
}
