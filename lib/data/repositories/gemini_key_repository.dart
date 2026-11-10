import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/result.dart';
import '../services/gemini_key_service.dart';

enum GeminiKeyError { invalid }

class GeminiKeyRepository {
  GeminiKeyRepository(this._service);
  final GeminiKeyService _service;

  /// The stored key; null when there is none or it cannot be read.
  Future<String?> load() async => switch (await _service.read()) {
    Ok(:final value) when value != null && value.isNotEmpty => value,
    _ => null,
  };

  /// Saves the key without the spaces around it (a paste often brings them). A key
  /// with a space or a line break inside is not a key.
  Future<Result<String>> save(String input) async {
    final key = input.trim();
    if (key.isEmpty || key.contains(RegExp(r'\s'))) {
      return const Failure(GeminiKeyError.invalid);
    }
    return switch (await _service.write(key)) {
      Ok() => Ok(key),
      Failure(:final error) => Failure(error),
    };
  }

  Future<Result<void>> clear() => _service.delete();
}

final geminiKeyRepositoryProvider = Provider(
  (ref) => GeminiKeyRepository(ref.watch(geminiKeyServiceProvider)),
);
