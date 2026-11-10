import 'dart:async';

import 'package:buyonce/core/theme/style_variant.dart';
import 'package:buyonce/presentation/view_models/settings/style_variant_view_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Runs before every test file: the tests check behaviour on the first design, whose
/// texts and sizes do not change when a new design is tried.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  defaultStyleVariant = StyleVariant.d1;
  // Date names of every language (the app loads them with its localizations).
  await initializeDateFormatting();
  // Empty stored settings for every test; without a mock the read never finishes.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  await testMain();
}
