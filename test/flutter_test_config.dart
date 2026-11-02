import 'dart:async';

import 'package:buyonce/core/theme/style_variant.dart';
import 'package:buyonce/presentation/view_models/settings/style_variant_view_model.dart';

/// Runs before every test file: the tests check behaviour on the first design, whose
/// texts and sizes do not change when a new design is tried.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  defaultStyleVariant = StyleVariant.d1;
  await testMain();
}
