import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'push_service.dart';

/// FCM token in `users/{uid}` (private to the user; one token, the newest phone wins).
class FirebasePushService implements PushService {
  FirebasePushService({FirebaseMessaging? messaging, FirebaseFirestore? db})
    : _messaging = messaging ?? FirebaseMessaging.instance,
      _db = db ?? FirebaseFirestore.instance;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;
  StreamSubscription<String>? _refresh;
  String? _userId;

  DocumentReference<Map<String, dynamic>> _doc(String userId) =>
      _db.collection('users').doc(userId);

  @override
  Future<void> register(String userId) async {
    if (_userId == userId) return;
    await _refresh?.cancel();
    _userId = userId;
    try {
      await _messaging.requestPermission();
      // Deprecated in favour of an installation id; this registration token is the one
      // the push test (plan step 12) proved with FCM v1.
      // ignore: deprecated_member_use
      final token = await _messaging.getToken();
      if (_userId != userId) return; // signed out or switched while waiting
      if (token != null) {
        // Not awaited: offline the write completes only after the server answers.
        unawaited(_save(userId, token));
      }
      // ignore: deprecated_member_use
      _refresh = _messaging.onTokenRefresh.listen((t) => _save(userId, t));
    } catch (error) {
      debugPrint('push registration failed: $error');
    }
  }

  Future<void> _save(String userId, String token) =>
      _doc(userId)
          .set({'fcmToken': token, 'updatedAt': FieldValue.serverTimestamp()})
          .catchError((Object e) => debugPrint('token write refused: $e'));

  @override
  Future<void> unregister(String userId) async {
    await _refresh?.cancel();
    _refresh = null;
    _userId = null;
    try {
      await _doc(userId).delete().timeout(const Duration(seconds: 5));
    } catch (error) {
      debugPrint(
        'token removal failed: $error',
      ); // offline: the Worker drops it later
    }
  }
}
