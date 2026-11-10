import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/result.dart';
import '../../core/utils/result_x.dart';

/// Raw key-value storage of the settings on the device.
class SettingsService {
  SettingsService([Future<SharedPreferences>? prefs])
    : _prefs = prefs ?? SharedPreferences.getInstance();
  final Future<SharedPreferences> _prefs;

  Future<Result<SharedPreferences>> _open() async {
    try {
      return Ok(await _prefs);
    } catch (e) {
      return Failure(e);
    }
  }

  Future<Result<bool?>> getBool(String key) async =>
      (await _open()).map((p) => p.getBool(key));

  Future<Result<int?>> getInt(String key) async =>
      (await _open()).map((p) => p.getInt(key));

  Future<Result<String?>> getString(String key) async =>
      (await _open()).map((p) => p.getString(key));

  Future<Result<void>> setBool(String key, bool value) =>
      _write((p) => p.setBool(key, value));

  Future<Result<void>> setInt(String key, int value) =>
      _write((p) => p.setInt(key, value));

  Future<Result<void>> setString(String key, String value) =>
      _write((p) => p.setString(key, value));

  Future<Result<void>> remove(String key) => _write((p) => p.remove(key));

  Future<Result<void>> _write(
    Future<bool> Function(SharedPreferences prefs) action,
  ) async {
    final opened = await _open();
    if (opened case Failure(:final error)) return Failure(error);
    try {
      await action((opened as Ok<SharedPreferences>).value);
      return const Ok(null);
    } catch (e) {
      return Failure(e);
    }
  }
}

final settingsServiceProvider = Provider((ref) => SettingsService());
