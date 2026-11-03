import 'dart:async';

import 'package:buyonce/core/theme/style_variant.dart';
import 'package:buyonce/presentation/view_models/settings/style_variant_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Runs before every test file: the tests check behaviour on the first design, whose
/// texts and sizes do not change when a new design is tried.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  defaultStyleVariant = StyleVariant.d1;
  // Empty stored settings for every test; without a mock the read never finishes.
  setUp(() => SharedPreferences.setMockInitialValues({}));
  await testMain();
}
