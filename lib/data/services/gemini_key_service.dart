import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/utils/result.dart';

/// The user's own Gemini API key, kept in the platform's encrypted storage (Android
/// Keystore), one key per device.
class GeminiKeyService {
  GeminiKeyService([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;

  static const _key = 'geminiApiKey';

  Future<Result<String?>> read() async {
    try {
      return Ok(await _storage.read(key: _key));
    } catch (e) {
      return Failure(e);
    }
  }

  Future<Result<void>> write(String value) async {
    try {
      await _storage.write(key: _key, value: value);
      return const Ok(null);
    } catch (e) {
      return Failure(e);
    }
  }

  Future<Result<void>> delete() async {
    try {
      await _storage.delete(key: _key);
      return const Ok(null);
    } catch (e) {
      return Failure(e);
    }
  }
}

final geminiKeyServiceProvider = Provider((ref) => GeminiKeyService());
