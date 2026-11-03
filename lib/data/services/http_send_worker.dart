import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'send_worker.dart';

/// `POST {baseUrl}/send` with the caller's ID token; the body holds ids only.
class HttpSendWorker implements SendWorker {
  HttpSendWorker(this.baseUrl, {FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final String baseUrl;
  final FirebaseAuth _auth;

  @override
  Future<void> finishSend(String groupId, String tripId) =>
      _post('send', {'groupId': groupId, 'tripId': tripId});

  @override
  Future<void> finishAsk(String groupId, List<String> productIds) =>
      _post('ask', {'groupId': groupId, 'productIds': productIds});

  Future<void> _post(String path, Map<String, Object> body) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final token = await _auth.currentUser?.getIdToken();
      if (token == null) return;
      final request = await client.postUrl(Uri.parse('$baseUrl/$path'));
      request.headers
        ..contentType = ContentType.json
        ..set('authorization', 'Bearer $token');
      request.write(jsonEncode(body));
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      await response.drain<void>();
      if (response.statusCode != 200) {
        debugPrint('worker /$path answered ${response.statusCode}');
      }
    } catch (error) {
      // The server finishes the send by itself later (cron lease).
      debugPrint('worker /$path unreachable: $error');
    } finally {
      client.close(force: true);
    }
  }
}
