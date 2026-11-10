import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/result.dart';
import '../../domain/models/gemini_task.dart';
import '../services/gemini_api.dart';
import '../services/gemini_key_service.dart';
import '../services/settings_service.dart';

/// Why the list of models of a key could not be read.
enum ModelListError { noKey, badKey, offline, failed }

/// The models a task tries (stored on the device, one JSON list per task) and the models
/// the user's key can use (asked from Google when the picker opens).
class GeminiModelsRepository {
  GeminiModelsRepository(this._settings, this._api, this._keys);
  final SettingsService _settings;
  final GeminiApi _api;
  final GeminiKeyService _keys;

  static String _storeKey(GeminiTask task) => 'geminiModels.${task.name}';

  /// The stored list; the task's default when there is none or it is unreadable or empty.
  Future<List<String>> load(GeminiTask task) async {
    final stored = await _settings.getString(_storeKey(task));
    if (stored case Ok(:final value) when value != null) {
      try {
        final json = jsonDecode(value);
        if (json is List) {
          final ids = [
            for (final id in json)
              if (id is String && id.trim().isNotEmpty) id.trim(),
          ];
          if (ids.isNotEmpty) return ids;
        }
      } catch (_) {}
    }
    return task.defaultModels;
  }

  Future<Result<void>> save(GeminiTask task, List<String> models) =>
      _settings.setString(_storeKey(task), jsonEncode(models));

  /// Back to the task's default list.
  Future<Result<void>> reset(GeminiTask task) =>
      _settings.remove(_storeKey(task));

  /// Names a model id must not contain to be offered: speech, images, live audio,
  /// embeddings, robots, computer control, transcription, music, research agents.
  static const _notForText = [
    'tts',
    'image',
    'live',
    'audio',
    'embedding',
    'robotics',
    'computer',
    'transcribe',
    'lyria',
    'deep-research',
    'antigravity',
    'banana',
  ];

  /// The models of one `ListModels` page that can answer a question about a photo:
  /// `generateContent` is supported and the id is not one of the special kinds. Sorted by
  /// display name.
  static List<GeminiModelInfo> usable(Object? models) {
    if (models is! List) return const [];
    final found = <GeminiModelInfo>[];
    for (final m in models) {
      if (m is! Map) continue;
      final name = m['name'];
      final methods = m['supportedGenerationMethods'];
      if (name is! String ||
          methods is! List ||
          !methods.contains('generateContent')) {
        continue;
      }
      final id = name.replaceFirst('models/', '');
      if (_notForText.any(id.contains)) continue;
      final display = m['displayName'];
      found.add(
        GeminiModelInfo(
          id,
          display is String && display.isNotEmpty ? display : id,
        ),
      );
    }
    return found;
  }

  /// Every usable model of the key, all pages, sorted by display name.
  Future<Result<List<GeminiModelInfo>>> available() async {
    final stored = await _keys.read();
    final key = switch (stored) {
      Ok(:final value) => value,
      Failure() => null,
    };
    if (key == null || key.isEmpty) return const Failure(ModelListError.noKey);
    final all = <GeminiModelInfo>[];
    String? token;
    // A page holds up to 100 models; ten pages is far more than Google offers.
    for (var page = 0; page < 10; page++) {
      final result = await _api.listModels(apiKey: key, pageToken: token);
      final GeminiReply reply;
      switch (result) {
        case Failure(error: GeminiNetworkError.offline):
          return const Failure(ModelListError.offline);
        case Failure():
          return const Failure(ModelListError.failed);
        case Ok(:final value):
          reply = value;
      }
      if (reply.status == 400 || reply.status == 401 || reply.status == 403) {
        return const Failure(ModelListError.badKey);
      }
      if (reply.status != 200) return const Failure(ModelListError.failed);
      all.addAll(usable(reply.json?['models']));
      final next = reply.json?['nextPageToken'];
      if (next is! String || next.isEmpty) break;
      token = next;
    }
    all.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    return Ok(all);
  }
}

final geminiModelsRepositoryProvider = Provider(
  (ref) => GeminiModelsRepository(
    ref.watch(settingsServiceProvider),
    ref.watch(geminiApiProvider),
    ref.watch(geminiKeyServiceProvider),
  ),
);
