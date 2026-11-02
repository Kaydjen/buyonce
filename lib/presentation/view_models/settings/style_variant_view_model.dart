import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/style_variant.dart';

/// The design shown at start. Widget tests pin it to the first design (see
/// `test/flutter_test_config.dart`), so the tests do not follow design experiments.
StyleVariant defaultStyleVariant = StyleVariant.d7;

/// The style trial: the variant shown, kept in memory only. Settings offers the switch
/// in debug builds; release builds show [defaultStyleVariant].
class StyleVariantViewModel extends Notifier<StyleVariant> {
  @override
  StyleVariant build() => defaultStyleVariant;

  void select(StyleVariant variant) => state = variant;
}

final styleVariantProvider =
    NotifierProvider<StyleVariantViewModel, StyleVariant>(
      StyleVariantViewModel.new,
    );
