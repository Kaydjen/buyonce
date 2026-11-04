import 'package:buyonce/core/theme/style_variant.dart';
import 'package:buyonce/data/services/in_memory_group_service.dart';
import 'package:buyonce/data/services/in_memory_list_service.dart';
import 'package:buyonce/data/services/service_providers.dart';
import 'package:buyonce/domain/models/app_settings.dart';
import 'package:buyonce/main.dart';
import 'package:buyonce/presentation/view_models/settings/settings_view_model.dart';
import 'package:buyonce/presentation/view_models/settings/style_variant_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Texts that are drawn on top of each other (a title under its button): not an overflow,
/// so the other layout tests do not see it.
List<String> overlaps(WidgetTester tester) {
  final texts = <(String, Rect)>[];
  for (final e in find.byType(RichText).hitTestable().evaluate()) {
    final box = e.renderObject;
    if (box is! RenderParagraph || !box.hasSize) continue;
    final text = box.text.toPlainText().trim();
    if (text.isEmpty) continue;
    texts.add((text, box.localToGlobal(Offset.zero) & box.size));
  }
  final found = <String>[];
  for (var i = 0; i < texts.length; i++) {
    for (var j = i + 1; j < texts.length; j++) {
      final cut = texts[i].$2.intersect(texts[j].$2);
      if (cut.width > 2 && cut.height > 4) {
        found.add('"${texts[i].$1}" over "${texts[j].$1}"');
      }
    }
  }
  return found;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final language in [LanguageChoice.en, LanguageChoice.uk]) {
    for (final width in [360.0, 411.0]) {
      for (final scale in TextScaleChoice.values) {
        testWidgets(
          'no text over another: ${language.name} $width ${scale.name}',
          (tester) async {
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  inMemoryListServiceProvider.overrideWithValue(
                    InMemoryListService(),
                  ),
                  inMemoryGroupServiceProvider.overrideWithValue(
                    InMemoryGroupService(),
                  ),
                ],
                child: const BuyOnceApp(),
              ),
            );
            await tester.pumpAndSettle();
            final container = ProviderScope.containerOf(
              tester.element(find.byType(MaterialApp)),
            );
            // The look of the app; the other tests use the flat baseline.
            container
                .read(styleVariantProvider.notifier)
                .select(StyleVariant.d7);
            final settings = container.read(settingsProvider.notifier);
            await settings.setLanguage(language);
            await settings.setTextScale(scale);
            await tester.pumpAndSettle();

            final problems = <String>[];
            void check(String screen) {
              for (final o in overlaps(tester)) {
                problems.add('$screen: $o');
              }
            }

            check('shop');
            await tester.tap(find.byKey(const Key('tabPlan')));
            await tester.pumpAndSettle();
            check('plan');
            await tester.tap(find.byKey(const Key('groupButton')));
            await tester.pumpAndSettle();
            check('group sheet');
            tester.state<NavigatorState>(find.byType(Navigator).first).pop();
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const Key('menuButton')));
            await tester.pumpAndSettle();
            check('menu');
            tester.state<NavigatorState>(find.byType(Navigator).first).pop();
            await tester.pumpAndSettle();
            expect(problems, isEmpty);
          },
        );
      }
    }
  }
}
