import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/result.dart';
import '../services/settings_service.dart';

/// The pairs the user has confirmed between a printed receipt line and a product
/// ("JajaSciol M 10szt" is "Яйця"), kept on this phone, per list. A line that is known
/// here is ticked without asking the model, so the app makes fewer mistakes the longer
/// it is used. Keys come from `printedKey`; values are product ids.
///
/// Stored as one JSON text (`receiptAliases`): `{listId: {printedKey: productId}}`. A
/// damaged text is read as empty.
class ReceiptAliasRepository {
  ReceiptAliasRepository(this._settings);
  final SettingsService _settings;

  static const storeKey = 'receiptAliases';

  /// Most pairs kept per list; the oldest go first.
  static const maxPerList = 500;

  Future<Map<String, Map<String, String>>> _all() async {
    final stored = await _settings.getString(storeKey);
    if (stored case Ok(:final value) when value != null) {
      try {
        final json = jsonDecode(value);
        if (json is Map) {
          return {
            for (final e in json.entries)
              if (e.key is String && e.value is Map)
                e.key as String: {
                  for (final p in (e.value as Map).entries)
                    if (p.key is String &&
                        p.value is String &&
                        (p.key as String).isNotEmpty)
                      p.key as String: p.value as String,
                },
          };
        }
      } catch (_) {}
    }
    return {};
  }

  Future<void> _save(Map<String, Map<String, String>> all) async {
    await _settings.setString(storeKey, jsonEncode(all));
  }

  /// printed key -> product id of the list.
  Future<Map<String, String>> load(String listId) async =>
      (await _all())[listId] ?? const {};

  /// Remembers pairs; a key that is already known points at its new product.
  Future<void> learn(String listId, Map<String, String> pairs) async {
    if (pairs.isEmpty) return;
    final all = await _all();
    final mine = {...?all[listId]};
    for (final e in pairs.entries) {
      if (e.key.isEmpty) continue;
      mine.remove(e.key); // goes to the end: the newest
      mine[e.key] = e.value;
    }
    while (mine.length > maxPerList) {
      mine.remove(mine.keys.first);
    }
    all[listId] = mine;
    await _save(all);
  }

  /// Forgets pairs the user turned down.
  Future<void> forget(String listId, Iterable<String> keys) async {
    final all = await _all();
    final mine = all[listId];
    if (mine == null) return;
    var changed = false;
    for (final k in keys) {
      changed = mine.remove(k) != null || changed;
    }
    if (changed) await _save(all);
  }
}

final receiptAliasRepositoryProvider = Provider(
  (ref) => ReceiptAliasRepository(ref.watch(settingsServiceProvider)),
);
