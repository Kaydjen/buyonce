import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/result.dart';
import '../../../data/repositories/name_suggestion_repository.dart';
import '../../../data/services/photo_service.dart';
import '../../../domain/models/gemini_outcome.dart';
import '../../../domain/models/gemini_task.dart';
import '../settings/gemini_models_view_model.dart';

class NameSuggestionState {
  const NameSuggestionState({
    this.busy = false,
    this.names = const [],
    this.problem,
  });

  /// A photo is being read: the camera icon shows a spinner.
  final bool busy;

  /// The names the last photo gave, to pick from.
  final List<String> names;

  /// Why the last try gave nothing; the screen shows it once and calls [problemShown].
  final GeminiOutcome? problem;
}

/// "Name this item from a photo" on the Add products screen: camera, Gemini, chips. The
/// photo stays in memory so a failed try can be repeated without a new shot.
class NameSuggestionViewModel extends Notifier<NameSuggestionState> {
  static const photoSide = 768.0;
  static const photoQuality = 80;

  Uint8List? _photo;

  @override
  NameSuggestionState build() => const NameSuggestionState();

  /// Opens the camera, then asks for names. [language] is the English name of the app
  /// language ("Ukrainian").
  Future<void> takePhoto(String language) async {
    if (state.busy) return;
    // The camera takes seconds: the connection to Google is opened meanwhile.
    unawaited(ref.read(nameSuggestionRepositoryProvider).warmUp());
    final taken = await ref
        .read(photoServiceProvider)
        .takePhoto(maxSide: photoSide, quality: photoQuality);
    if (!ref.mounted) return;
    switch (taken) {
      case Ok(:final value) when value != null:
        _photo = value;
        await _suggest(language);
      case Ok():
        break; // the camera was closed
      case Failure():
        _photo = null;
        state = const NameSuggestionState(problem: GeminiFailed());
    }
  }

  /// Asks again about the photo already taken (a new shot when there is none).
  Future<void> retry(String language) async {
    if (state.busy) return;
    if (_photo == null) return takePhoto(language);
    await _suggest(language);
  }

  /// A photo taken before Android killed the app is not wasted.
  Future<void> recoverLost(String language) async {
    final lost = await ref.read(photoServiceProvider).recoverLostPhoto();
    if (!ref.mounted || lost == null || state.busy) return;
    _photo = lost;
    await _suggest(language);
  }

  Future<void> _suggest(String language) async {
    state = const NameSuggestionState(busy: true);
    final models = await ref.read(
      geminiModelsProvider(GeminiTask.items).future,
    );
    final result = await ref
        .read(nameSuggestionRepositoryProvider)
        .suggest(_photo!, language: language, models: models);
    if (!ref.mounted) return;
    state = switch (result) {
      SuggestedNames(:final names) => NameSuggestionState(names: names),
      NoSuggestions(:final outcome) => NameSuggestionState(problem: outcome),
    };
  }

  /// The chips go once a name is used.
  void clearNames() {
    if (state.names.isEmpty) return;
    state = NameSuggestionState(problem: state.problem, busy: state.busy);
  }

  void problemShown() {
    if (state.problem == null) return;
    state = NameSuggestionState(busy: state.busy, names: state.names);
  }
}

final nameSuggestionProvider =
    NotifierProvider.autoDispose<NameSuggestionViewModel, NameSuggestionState>(
      NameSuggestionViewModel.new,
    );
