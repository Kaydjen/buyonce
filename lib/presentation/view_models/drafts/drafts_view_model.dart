import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Names typed on the "Add products" screen but not added yet, newest first. One list
/// per group; they live in memory, so back and reopen keep them and a restart drops them.
class DraftsViewModel extends Notifier<List<String>> {
  DraftsViewModel(this.groupId);
  final String groupId;

  @override
  List<String> build() => const [];

  static String clean(String raw) => raw.trim();

  /// Same name (any case) is one draft.
  bool has(String raw) {
    final name = clean(raw).toLowerCase();
    return state.any((d) => d.toLowerCase() == name);
  }

  void add(String raw) {
    final name = clean(raw);
    if (name.isEmpty || has(name)) return;
    state = [name, ...state];
  }

  void remove(String name) => state = [
    for (final d in state)
      if (d != name) d,
  ];

  void clear() => state = const [];
}

final draftsViewModelProvider =
    NotifierProvider.family<DraftsViewModel, List<String>, String>(
      DraftsViewModel.new,
    );
