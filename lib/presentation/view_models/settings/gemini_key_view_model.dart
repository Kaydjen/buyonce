import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/result.dart';
import '../../../data/repositories/gemini_key_repository.dart';

/// The Gemini API key of this device: null when none is set.
class GeminiKeyViewModel extends AsyncNotifier<String?> {
  @override
  Future<String?> build() => ref.watch(geminiKeyRepositoryProvider).load();

  Future<Result<void>> save(String input) async {
    final result = await ref.read(geminiKeyRepositoryProvider).save(input);
    return switch (result) {
      Ok(:final value) => () {
        state = AsyncData(value);
        return const Ok<void>(null);
      }(),
      Failure(:final error) => Failure(error),
    };
  }

  Future<void> clear() async {
    final result = await ref.read(geminiKeyRepositoryProvider).clear();
    if (result is Ok<void>) state = const AsyncData(null);
  }
}

final geminiKeyProvider = AsyncNotifierProvider<GeminiKeyViewModel, String?>(
  GeminiKeyViewModel.new,
);

/// The key as the settings row shows it: only its last four characters.
String maskedKey(String key) =>
    '••••${key.length > 4 ? key.substring(key.length - 4) : key}';
