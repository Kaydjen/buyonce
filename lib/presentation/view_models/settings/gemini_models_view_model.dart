import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/result.dart';
import '../../../data/repositories/gemini_models_repository.dart';
import '../../../domain/models/gemini_task.dart';

/// The models a task tries, in order. Every change is saved at once; the client forgets
/// its limits by itself when the list differs from the one it knew.
class GeminiModelsViewModel extends AsyncNotifier<List<String>> {
  GeminiModelsViewModel(this.task);
  final GeminiTask task;

  @override
  Future<List<String>> build() =>
      ref.watch(geminiModelsRepositoryProvider).load(task);

  List<String> get _current => state.value ?? task.defaultModels;

  Future<void> _set(List<String> models) async {
    state = AsyncData(models);
    await ref.read(geminiModelsRepositoryProvider).save(task, models);
  }

  /// Moves a model to [newIndex], its place in the list once it is out of its old one
  /// (what `ReorderableListView.onReorderItem` reports).
  Future<void> reorder(int oldIndex, int newIndex) async {
    final models = [..._current];
    if (oldIndex < 0 || oldIndex >= models.length) return;
    if (newIndex == oldIndex || newIndex < 0 || newIndex >= models.length) {
      return;
    }
    models.insert(newIndex, models.removeAt(oldIndex));
    await _set(models);
  }

  /// The last model cannot be removed: a task with no model asks nobody.
  Future<void> remove(String id) async {
    final models = _current;
    if (models.length <= 1 || !models.contains(id)) return;
    await _set([
      for (final m in models)
        if (m != id) m,
    ]);
  }

  /// Adds a model id at the end; false when it is empty or already there.
  Future<bool> add(String raw) async {
    final id = raw.trim().replaceFirst('models/', '');
    if (id.isEmpty || id.contains(RegExp(r'\s'))) return false;
    final models = _current;
    if (models.contains(id)) return false;
    await _set([...models, id]);
    return true;
  }

  Future<void> reset() async {
    state = AsyncData(task.defaultModels);
    await ref.read(geminiModelsRepositoryProvider).reset(task);
  }

  bool get isDefault {
    final a = _current;
    final b = task.defaultModels;
    return a.length == b.length &&
        [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((e) => e);
  }
}

final geminiModelsProvider =
    AsyncNotifierProvider.family<
      GeminiModelsViewModel,
      List<String>,
      GeminiTask
    >(GeminiModelsViewModel.new);

/// The models the user's key can use; read when the picker opens.
final availableModelsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(geminiModelsRepositoryProvider).available(),
);

/// What the picker shows: a list, or the reason there is none.
extension AvailableModels on AsyncValue<Result<List<GeminiModelInfo>>> {
  ModelListError? get listError => switch (value) {
    Failure(error: final ModelListError e) => e,
    Failure() => ModelListError.failed,
    _ => hasError ? ModelListError.failed : null,
  };
}
