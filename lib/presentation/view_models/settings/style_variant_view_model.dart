import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/style_variant.dart';

/// The style trial: the variant shown, kept in memory only. Settings offers the switch
/// in debug builds; release builds show the default, [StyleVariant.vaulto].
class StyleVariantViewModel extends Notifier<StyleVariant> {
  @override
  StyleVariant build() => StyleVariant.vaulto;

  void select(StyleVariant variant) => state = variant;
}

final styleVariantProvider =
    NotifierProvider<StyleVariantViewModel, StyleVariant>(
      StyleVariantViewModel.new,
    );
