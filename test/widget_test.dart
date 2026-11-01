import 'package:buyonce/core/utils/result.dart';
import 'package:buyonce/main.dart';
import 'package:buyonce/presentation/view_models/groups/groups_view_model.dart';
import 'package:buyonce/presentation/view_models/list/list_view_model.dart';
import 'package:buyonce/presentation/widgets/flash_on_add.dart';
import 'package:buyonce/presentation/widgets/product_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: BuyOnceApp()));
  await tester.pumpAndSettle();
}

double sendOpacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(
      find.ancestor(
        of: find.byType(FilledButton),
        matching: find.byType(AnimatedOpacity),
      ),
    )
    .opacity;

/// A product row by name; the same text inside a text field does not count.
Finder rowNamed(String name) =>
    find.descendant(of: find.byType(ProductRow), matching: find.text(name));

Future<void> goShop(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('tabShop')));
  await tester.pumpAndSettle();
}

Future<void> goPlan(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('tabPlan')));
  await tester.pumpAndSettle();
}

/// Types into the Plan field without submitting.
Future<void> typeInField(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('addField')), text);
  await tester.pumpAndSettle();
}

Future<void> typeAndSubmit(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('addField')), text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

Future<void> openMenu(WidgetTester tester, String item) async {
  await tester.tap(find.byIcon(Icons.more_vert));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item));
  await tester.pumpAndSettle();
}

/// The selected bottom tab is the bold one.
String modeTitle(WidgetTester tester) {
  bool bold(String key) =>
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(Key(key)),
              matching: find.byType(Text),
            ),
          )
          .style!
          .fontWeight ==
      FontWeight.w500;
  return bold('tabShop') ? 'Shop' : 'Plan';
}

double listPixels(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position
    .pixels;

/// Strongest blink overlay among all rows, 0 when none is lit.
double flashAlpha(WidgetTester tester) {
  var best = 0.0;
  for (final c in tester.widgetList<Container>(
    find.descendant(
      of: find.byType(FlashOnAdd),
      matching: find.byType(Container),
    ),
  )) {
    final d = c.foregroundDecoration;
    if (d is BoxDecoration && d.color != null && d.color!.a > best) {
      best = d.color!.a;
    }
  }
  return best;
}

typedef Sample = ({double pixels, double alpha});

/// Steps time in 50 ms frames and records scroll offset and blink strength.
Future<List<Sample>> recordFlash(WidgetTester tester) async {
  final samples = <Sample>[];
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    samples.add((pixels: listPixels(tester), alpha: flashAlpha(tester)));
  }
  return samples;
}

void expectBlinkAfterScroll(List<Sample> timeline) {
  final settled = timeline.last.pixels;
  expect(
    timeline.map((s) => s.alpha).reduce((a, b) => a > b ? a : b),
    greaterThan(0.05),
  );
  for (final s in timeline.where((s) => s.alpha > 0)) {
    expect(s.pixels, settled);
  }
}

/// Imitates the partner marking products; the lists reload like after a sync.
Future<void> partnerMarks(WidgetTester tester, List<String> ids) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(Scaffold)),
  );
  final repo = container.read(listRepositoryProvider);
  for (final id in ids) {
    await repo.toggleMark(id, 'partner');
  }
  await container.read(listViewModelProvider.notifier).refresh();
  await tester.pumpAndSettle();
}

/// A mark inside the row of [name]: Icons.circle stands for another member's mark
/// ("check + name"), any other icon is found only outside of it.
Finder markIn(String name, IconData icon) {
  final row = find.ancestor(
    of: rowNamed(name),
    matching: find.byType(ProductRow),
  );
  if (icon == Icons.circle) {
    return find.descendant(
      of: row,
      matching: find.byKey(const Key('partnerMark')),
    );
  }
  return find.descendant(
    of: row,
    matching: find.byWidgetPredicate(
      (w) => w is Icon && w.icon == icon && w.key == null,
    ),
  );
}

/// Opens the group sheet from the header and picks [name].
Future<void> switchGroup(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const Key('groupButton')));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, name));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens in Plan with the whole catalog and the add field', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(modeTitle(tester), 'Plan');
    expect(find.byKey(const Key('addField')), findsOneWidget);
    expect(find.text('LIST'), findsOneWidget);
    expect(rowNamed('Cheese'), findsOneWidget);
    expect(sendOpacity(tester), 0);
  });

  testWidgets('Shop shows only needed products, no field, no label', (
    tester,
  ) async {
    await pumpApp(tester);
    await goShop(tester);
    expect(modeTitle(tester), 'Shop');
    expect(rowNamed('Milk'), findsOneWidget);
    expect(rowNamed('Cheese'), findsNothing);
    expect(find.byKey(const Key('addField')), findsNothing);
    expect(find.text('LIST'), findsNothing);
    expect(find.byIcon(Icons.search), findsOneWidget);
  });

  testWidgets('Shop search offers frequent products; a tap takes one', (
    tester,
  ) async {
    await pumpApp(tester);
    await goShop(tester);
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    // Before typing: frequent products outside the plan, not the planned ones.
    expect(rowNamed('Bread'), findsOneWidget);
    expect(rowNamed('Milk'), findsNothing);
    expect(rowNamed('Water'), findsNothing); // never bought: not offered
    await tester.tap(find.text('Bread'));
    await tester.pumpAndSettle();
    expect(sendOpacity(tester), 1);

    // Typing reaches the whole catalog, taken rows keep their check in place.
    await typeInField(tester, 'Water');
    expect(rowNamed('Water'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('addField')), findsNothing);
    expect(markIn('Bread', Icons.check), findsOneWidget);

    // The taken product leaves with Send and stays in the catalog.
    await tester.tap(find.byKey(const Key('sendButton')));
    await tester.pumpAndSettle();
    expect(rowNamed('Bread'), findsNothing);
    await goPlan(tester);
    expect(rowNamed('Bread'), findsOneWidget);
  });

  testWidgets('Shop search: Enter on a unique name takes it and closes', (
    tester,
  ) async {
    await pumpApp(tester);
    await goShop(tester);
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await typeAndSubmit(tester, 'Water');
    expect(find.byKey(const Key('addField')), findsNothing);
    expect(markIn('Water', Icons.check), findsOneWidget);
    expect(sendOpacity(tester), 1);
  });

  testWidgets('Shop search: an unknown name is created taken, not planned', (
    tester,
  ) async {
    await pumpApp(tester);
    await goShop(tester);
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await typeAndSubmit(tester, 'Nuts');
    expect(markIn('Nuts', Icons.check), findsOneWidget);
    expect(sendOpacity(tester), 1);
    await tester.tap(find.byKey(const Key('sendButton')));
    await tester.pumpAndSettle();
    expect(rowNamed('Nuts'), findsNothing);
    await goPlan(tester);
    expect(rowNamed('Nuts'), findsOneWidget);
  });

  testWidgets('groups: each one shows its own list', (tester) async {
    await pumpApp(tester);
    expect(find.text('Home'), findsOneWidget);
    expect(rowNamed('Cheese'), findsOneWidget);
    expect(rowNamed('Carrots'), findsNothing);

    await switchGroup(tester, 'Mom');
    expect(find.text('Mom'), findsOneWidget);
    expect(rowNamed('Carrots'), findsOneWidget);
    expect(rowNamed('Cheese'), findsNothing);

    // A mark in one group does not show in another.
    await goShop(tester);
    await tester.tap(find.text('Carrots'));
    await tester.pumpAndSettle();
    expect(sendOpacity(tester), 1);
    await switchGroup(tester, 'Work');
    expect(rowNamed('Paper cups'), findsOneWidget);
    expect(sendOpacity(tester), 0);

    await switchGroup(tester, 'Home');
    expect(rowNamed('Milk'), findsOneWidget);
    expect(sendOpacity(tester), 0);
    await switchGroup(tester, 'Mom');
    expect(sendOpacity(tester), 1);
  });

  testWidgets('the last screen is kept; unsent marks open Shop', (
    tester,
  ) async {
    await pumpApp(tester);
    await goShop(tester);
    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();
    await goPlan(tester);

    // Mom has no marks: the last used screen (Plan) stays.
    await switchGroup(tester, 'Mom');
    expect(modeTitle(tester), 'Plan');
    // Home has my unsent mark: it opens in Shop.
    await switchGroup(tester, 'Home');
    expect(modeTitle(tester), 'Shop');
    expect(sendOpacity(tester), 1);
  });

  testWidgets('idle trip of a group is sent while another group is shown', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          autoNotifyDelayProvider.overrideWithValue(
            const Duration(minutes: 10),
          ),
        ],
        child: const BuyOnceApp(),
      ),
    );
    await tester.pumpAndSettle();
    await goShop(tester);
    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();
    await switchGroup(tester, 'Mom');
    await tester.pump(const Duration(minutes: 11));
    await switchGroup(tester, 'Home');
    expect(sendOpacity(tester), 0);
    expect(markIn('Milk', Icons.check), findsNothing);
  });

  testWidgets('tap marks a product and send clears the trip', (tester) async {
    await pumpApp(tester);
    await goShop(tester);
    expect(sendOpacity(tester), 0);

    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();
    expect(sendOpacity(tester), 1);
    expect(find.byKey(const Key('sendButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('sendButton')));
    await tester.pumpAndSettle();
    expect(sendOpacity(tester), 0);
  });

  testWidgets('sent planned product leaves the plan', (tester) async {
    await pumpApp(tester);
    double top(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(top('Milk') < top('Buns'), isTrue);

    await goShop(tester);
    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sendButton')));
    await tester.pumpAndSettle();
    expect(rowNamed('Milk'), findsNothing);

    await goPlan(tester);
    expect(top('Milk') > top('Buns'), isTrue);
  });

  testWidgets('sort by alphabet reorders the list once', (tester) async {
    await pumpApp(tester);
    double top(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(top('Bread') < top('Bananas'), isTrue);

    await openMenu(tester, 'Sort');
    await tester.tap(find.text('Alphabetical'));
    await tester.pumpAndSettle();
    expect(top('Bananas') < top('Bread'), isTrue);
  });

  testWidgets('long press drag moves a product', (tester) async {
    await pumpApp(tester);
    double top(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(top('Bread') < top('Eggs'), isTrue);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Bread')),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.moveBy(const Offset(0, 120));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(top('Eggs') < top('Bread'), isTrue);
  });

  testWidgets('quick add applies a past plan', (tester) async {
    await pumpApp(tester);
    double top(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(top('Bread') > top('Salad'), isTrue);

    await openMenu(tester, 'Templates');
    expect(find.text('TEMPLATES'), findsOneWidget);
    await tester.tap(find.text('Bread, Eggs, Cheese'));
    await tester.pumpAndSettle();
    expect(top('Bread') < top('Salad'), isTrue);
  });

  testWidgets('Enter on an unknown name adds it planned, on top of the list', (
    tester,
  ) async {
    await pumpApp(tester);
    double top(String name) => tester.getTopLeft(find.text(name)).dy;
    await typeAndSubmit(tester, 'Nuts');
    expect(rowNamed('Nuts'), findsOneWidget);
    expect(top('Nuts') < top('Milk'), isTrue);
    expect(find.widgetWithText(TextField, 'Nuts'), findsNothing);
    expect(sendOpacity(tester), 0);

    await goShop(tester);
    expect(rowNamed('Nuts'), findsOneWidget);
  });

  testWidgets('the Add row adds the typed name', (tester) async {
    await pumpApp(tester);
    await typeInField(tester, 'Nuts');
    expect(rowNamed('Nuts'), findsNothing);
    await tester.tap(find.text('+ Add "Nuts"'));
    await tester.pumpAndSettle();
    expect(rowNamed('Nuts'), findsOneWidget);
    expect(find.text('+ Add "Nuts"'), findsNothing);
  });

  testWidgets('Enter on an existing name plans it, no duplicate', (
    tester,
  ) async {
    await pumpApp(tester);
    await typeAndSubmit(tester, 'cheese');
    expect(rowNamed('Cheese'), findsOneWidget);
    await goShop(tester);
    expect(rowNamed('Cheese'), findsOneWidget);
    expect(sendOpacity(tester), 0);
  });

  testWidgets('Enter with several matches does nothing', (tester) async {
    await pumpApp(tester);
    await typeAndSubmit(tester, 'er');
    expect(find.widgetWithText(TextField, 'er'), findsOneWidget);
    expect(find.text('+ Add "er"'), findsNothing);
  });

  // The test font is wider than Roboto, so this is stricter than the real phone.
  testWidgets('header fits a 411 dp wide phone', (tester) async {
    tester.view.physicalSize = const Size(411, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(tester);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Shop: partner mark is a circle, mine a check, partner is read-only',
    (tester) async {
      await pumpApp(tester);
      await goShop(tester);
      await partnerMarks(tester, ['seed4']); // Salad
      expect(markIn('Salad', Icons.circle), findsOneWidget);
      expect(markIn('Salad', Icons.check), findsNothing);
      expect(sendOpacity(tester), 0);

      await tester.tap(find.text('Salad'));
      await tester.pumpAndSettle();
      expect(markIn('Salad', Icons.circle), findsOneWidget);
      expect(sendOpacity(tester), 0);

      await tester.tap(find.text('Buns'));
      await tester.pumpAndSettle();
      expect(markIn('Buns', Icons.check), findsOneWidget);
      expect(sendOpacity(tester), 1);

      // A second tap removes my mark silently.
      await tester.tap(find.text('Buns'));
      await tester.pumpAndSettle();
      expect(markIn('Buns', Icons.check), findsNothing);
      expect(sendOpacity(tester), 0);
    },
  );

  testWidgets('Notify closes only my trip, the partner mark stays', (
    tester,
  ) async {
    await pumpApp(tester);
    await goShop(tester);
    await partnerMarks(tester, ['seed4']);
    await tester.tap(find.text('Buns'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sendButton')));
    await tester.pumpAndSettle();
    expect(sendOpacity(tester), 0);
    expect(rowNamed('Buns'), findsNothing); // sent: no longer needed
    expect(markIn('Salad', Icons.circle), findsOneWidget);

    // A mark after Notify opens a new trip and shows the button again.
    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();
    expect(sendOpacity(tester), 1);
  });

  testWidgets('idle trip is sent after the pause counted from my last mark', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          autoNotifyDelayProvider.overrideWithValue(
            const Duration(minutes: 10),
          ),
        ],
        child: const BuyOnceApp(),
      ),
    );
    await tester.pumpAndSettle();
    await goShop(tester);

    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 9));
    expect(sendOpacity(tester), 1);

    // A new mark restarts the countdown.
    await tester.tap(find.text('Buns'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 9));
    expect(sendOpacity(tester), 1);

    // Planning is not a trip action: the countdown keeps running.
    await goPlan(tester);
    await tester.tap(find.text('Cheese'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 2));
    await tester.pumpAndSettle();
    expect(sendOpacity(tester), 0);
    expect(markIn('Buns', Icons.check), findsNothing);
  });

  testWidgets('removing the last mark stops the idle timer', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          autoNotifyDelayProvider.overrideWithValue(
            const Duration(minutes: 10),
          ),
        ],
        child: const BuyOnceApp(),
      ),
    );
    await tester.pumpAndSettle();
    await goShop(tester);
    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();
    expect(sendOpacity(tester), 0);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold)),
    );
    await tester.pump(const Duration(minutes: 11));
    final notices = await container
        .read(listRepositoryProvider)
        .getNotices('partner');
    expect((notices as Ok).value, isEmpty);
  });

  testWidgets('Plan: marked products show the mark in place and are locked', (
    tester,
  ) async {
    await pumpApp(tester);
    // Milk is planned; Bread is not.
    await partnerMarks(tester, ['seed0', 'seed1']);
    expect(markIn('Milk', Icons.circle), findsOneWidget);
    expect(markIn('Bread', Icons.circle), findsOneWidget);
    expect(sendOpacity(tester), 0);

    double top(String name) => tester.getTopLeft(find.text(name)).dy;
    final before = top('Buns');
    await goShop(tester);
    await tester.tap(find.text('Buns'));
    await tester.pumpAndSettle();
    await goPlan(tester);
    expect(markIn('Buns', Icons.check), findsOneWidget);
    expect(top('Buns'), before);

    // A marked product is locked in Plan: a tap neither unplans nor replans it.
    await tester.tap(find.text('Buns'));
    await tester.pumpAndSettle();
    expect(markIn('Buns', Icons.check), findsOneWidget);
    expect(top('Buns'), before);
    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();
    expect(markIn('Milk', Icons.circle), findsOneWidget);
    expect(top('Milk') < top('Salad'), isTrue);
  });

  testWidgets(
    'debug switch: act as the partner, notify, the other sees a notice',
    (tester) async {
      await pumpApp(tester);
      await goShop(tester);
      Future<void> switchTo(String label) async {
        await tester.longPress(find.byKey(const Key('groupButton')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text(label),
          ),
        );
        await tester.pumpAndSettle();
      }

      await switchTo('Anna');
      expect(find.text('Anna'), findsOneWidget); // the strip, not the sheet
      await tester.tap(find.text('Salad'));
      await tester.pumpAndSettle();
      expect(markIn('Salad', Icons.check), findsOneWidget);
      expect(find.byKey(const Key('sendButton')), findsOneWidget);
      await tester.tap(find.text('Buns'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sendButton')), findsOneWidget);

      await switchTo('Alex');
      expect(markIn('Salad', Icons.circle), findsOneWidget);
      expect(markIn('Buns', Icons.circle), findsOneWidget);
      await tester.tap(find.text('Salad'));
      await tester.pumpAndSettle();
      expect(markIn('Salad', Icons.circle), findsOneWidget);
      expect(sendOpacity(tester), 0);

      await switchTo('Anna');
      await tester.tap(find.byKey(const Key('sendButton')));
      await tester.pumpAndSettle();
      expect(rowNamed('Salad'), findsNothing); // sent: no longer needed

      await switchTo('Alex');
      expect(find.text('Anna bought: Salad, Buns'), findsOneWidget);
      await tester.tap(find.text('Anna bought: Salad, Buns'));
      await tester.pumpAndSettle();
      expect(find.textContaining('bought:'), findsNothing);

      await switchTo('Anna');
      await switchTo('Alex');
      expect(find.textContaining('bought:'), findsNothing);
    },
  );

  testWidgets(
    'Plan: a tapped search result gets a check in place, no regrouping',
    (tester) async {
      await pumpApp(tester);
      await typeInField(tester, 'er');
      expect(find.text('LIST'), findsNothing);
      double top(String name) => tester.getTopLeft(rowNamed(name)).dy;
      final before = [top('Butter'), top('Water')];
      expect(before[0] < before[1], isTrue);
      await tester.tap(rowNamed('Water'));
      await tester.pumpAndSettle();
      expect([top('Butter'), top('Water')], before);
      expect(find.text('LIST'), findsNothing);
      expect(
        find.descendant(
          of: find.ancestor(
            of: rowNamed('Water'),
            matching: find.byType(ProductRow),
          ),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Plan: closing the search regroups and blinks the activated row',
    (tester) async {
      await pumpApp(tester);
      await typeInField(tester, 'Water');
      await tester.tap(rowNamed('Water'));
      await tester.pumpAndSettle();
      expect(flashAlpha(tester), 0);
      await tester.tap(find.byIcon(Icons.close));
      final timeline = await recordFlash(tester);
      expect(find.text('LIST', skipOffstage: false), findsOneWidget);
      expectBlinkAfterScroll(timeline);
    },
  );

  testWidgets('Plan: the blink of a new product starts after the scroll', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(listPixels(tester), greaterThan(100));
    await tester.enterText(find.byKey(const Key('addField')), 'Nuts');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    final timeline = await recordFlash(tester);
    expectBlinkAfterScroll(timeline);
  });

  testWidgets('taken products are dimmed, never struck', (tester) async {
    await pumpApp(tester);
    await goShop(tester);
    await tester.tap(find.text('Milk'));
    await tester.tap(find.text('Buns'));
    await tester.pumpAndSettle();
    TextStyle style(String name) => tester.widget<Text>(find.text(name)).style!;
    expect(style('Milk').decoration, isNot(TextDecoration.lineThrough));
    expect(style('Buns').decoration, isNot(TextDecoration.lineThrough));
    expect(style('Buns').color, style('Milk').color);
    expect(style('Milk').color, isNot(style('Salad').color));
  });

  testWidgets('Sort is a Plan menu item, Shop menu has only Settings', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Sort'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await goShop(tester);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Sort'), findsNothing);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('Shop: Mark all takes the open products, Undo gives them back', (
    tester,
  ) async {
    await pumpApp(tester);
    await goShop(tester);
    await partnerMarks(tester, ['seed4']); // Salad is the partner's
    await tester.tap(find.byKey(const Key('markAll')));
    await tester.pumpAndSettle();
    for (final name in ['Milk', 'Buns', 'Frozen vegetables']) {
      expect(markIn(name, Icons.check), findsOneWidget);
    }
    expect(markIn('Salad', Icons.circle), findsOneWidget);
    expect(sendOpacity(tester), 1);
    expect(find.text('Marked: 3'), findsOneWidget);
    expect(find.byKey(const Key('markAll')), findsNothing);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(markIn('Milk', Icons.check), findsNothing);
    expect(markIn('Salad', Icons.circle), findsOneWidget);
    expect(sendOpacity(tester), 0);
    expect(find.byKey(const Key('markAll')), findsOneWidget);
  });

  testWidgets('Mark all is a Shop button and keeps my earlier marks', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.byKey(const Key('markAll')), findsNothing);
    await goShop(tester);
    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('markAll')));
    await tester.pumpAndSettle();
    expect(markIn('Milk', Icons.check), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    // Undo takes back only what Mark all added.
    expect(markIn('Milk', Icons.check), findsOneWidget);
    expect(markIn('Buns', Icons.check), findsNothing);
  });

  testWidgets('Send shows the count and the auto-send time', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          autoNotifyDelayProvider.overrideWithValue(const Duration(hours: 1)),
        ],
        child: const BuyOnceApp(),
      ),
    );
    await tester.pumpAndSettle();
    await goShop(tester);
    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();
    expect(find.text('Send 1'), findsOneWidget);
    final chip = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('autoChip')),
        matching: find.byType(Text),
      ),
    );
    expect(chip.data, matches(RegExp(r'^Auto · \d\d:\d\d$')));

    await tester.tap(find.text('Buns'));
    await tester.pumpAndSettle();
    expect(find.text('Send 2'), findsOneWidget);
  });

  testWidgets('the auto-send chip counts minutes in the last ten', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          autoNotifyDelayProvider.overrideWithValue(const Duration(minutes: 8)),
        ],
        child: const BuyOnceApp(),
      ),
    );
    await tester.pumpAndSettle();
    await goShop(tester);
    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();
    expect(find.text('Auto · in 8 min'), findsOneWidget);
    // Removing the last mark ends the countdown.
    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('autoChip')), findsNothing);
  });

  testWidgets('the auto-send chip counts seconds in the last minute', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          autoNotifyDelayProvider.overrideWithValue(
            const Duration(seconds: 30),
          ),
        ],
        child: const BuyOnceApp(),
      ),
    );
    await tester.pumpAndSettle();
    await goShop(tester);
    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();
    expect(find.textContaining(RegExp(r'^Auto · in \d\d? s$')), findsOneWidget);
    // Let the idle send fire so no timer is left pending.
    await tester.pump(const Duration(seconds: 25));
    await tester.pumpAndSettle();
  });

  testWidgets('presence strip and the name next to a check', (tester) async {
    await pumpApp(tester);
    await goShop(tester);
    expect(find.byKey(const Key('presence')), findsNothing);
    await partnerMarks(tester, ['seed4', 'seed0']);
    expect(find.text('Anna shopping, 2 taken'), findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(
          of: rowNamed('Salad'),
          matching: find.byType(ProductRow),
        ),
        matching: find.text('Anna'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('my mark is a bare check, a partner mark is check and name', (
    tester,
  ) async {
    await pumpApp(tester);
    await goShop(tester);
    await partnerMarks(tester, ['seed4']);
    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();
    String namesIn(String product) => tester
        .widgetList<Text>(
          find.descendant(
            of: find.ancestor(
              of: rowNamed(product),
              matching: find.byType(ProductRow),
            ),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data)
        .join('|');
    expect(namesIn('Milk'), 'Milk'); // mine: no name
    expect(namesIn('Salad'), 'Salad|Anna');
    final colour = tester
        .widget<Icon>(
          find.descendant(
            of: markIn('Salad', Icons.circle),
            matching: find.byIcon(Icons.check),
          ),
        )
        .color;
    expect(
      colour,
      isNot(tester.widget<Icon>(markIn('Milk', Icons.check)).color),
    );
  });

  testWidgets('a tap on a product another member took says so, once', (
    tester,
  ) async {
    await pumpApp(tester);
    await goShop(tester);
    await partnerMarks(tester, ['seed4']);
    await tester.tap(find.text('Salad'));
    await tester.pump();
    expect(find.text('Anna already bought this'), findsOneWidget);
    // A second tap replaces the note, it does not pile up.
    await tester.tap(find.text('Salad'));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    expect(find.byType(SnackBar), findsOneWidget);
    // It goes away by itself and the mark stays the partner's.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(markIn('Salad', Icons.circle), findsOneWidget);
    expect(sendOpacity(tester), 0);

    // My own product gives no note.
    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();
    expect(find.textContaining('already bought'), findsNothing);
  });

  testWidgets('a plan is deleted by its icon and comes back with Undo', (
    tester,
  ) async {
    await pumpApp(tester);
    await openMenu(tester, 'Templates');
    expect(find.text('Bread, Eggs, Cheese'), findsOneWidget);
    await tester.tap(find.byKey(const Key('delete-plan1')));
    await tester.pumpAndSettle();
    expect(find.text('Bread, Eggs, Cheese'), findsNothing);
    expect(find.text('Deleted'), findsOneWidget);

    await tester.tap(find.byKey(const Key('undoDelete')));
    await tester.pumpAndSettle();
    expect(find.text('Bread, Eggs, Cheese'), findsOneWidget);
    expect(find.text('Deleted'), findsNothing);
  });

  testWidgets('a plan is deleted by a swipe and stays deleted', (tester) async {
    await pumpApp(tester);
    await openMenu(tester, 'Templates');
    await tester.drag(find.text('Bread, Eggs, Cheese'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Bread, Eggs, Cheese'), findsNothing);
    // Closing and reopening the sheet shows the plan is really gone.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await openMenu(tester, 'Templates');
    expect(find.text('Bread, Eggs, Cheese'), findsNothing);
    expect(find.text('Milk, Frozen vegetables, Salad, Buns'), findsOneWidget);
  });

  testWidgets('Shop rows are 64 dp, Plan rows 56 dp', (tester) async {
    await pumpApp(tester);
    final plan = tester.getSize(find.byType(ProductRow).first).height;
    await goShop(tester);
    final shop = tester.getSize(find.byType(ProductRow).first).height;
    expect(plan, 56);
    expect(shop, 64);
  });

  testWidgets('a large system font does not break the screens', (tester) async {
    tester.view.physicalSize = const Size(411, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester);
    expect(tester.takeException(), isNull);

    await goShop(tester);
    await partnerMarks(tester, ['seed4']);
    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sendButton')), findsOneWidget);
    expect(find.byKey(const Key('autoChip')), findsOneWidget);
    expect(find.byKey(const Key('presence')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('groupButton')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
