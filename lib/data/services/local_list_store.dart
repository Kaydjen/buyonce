import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../core/utils/result.dart';
import 'in_memory_list_service.dart';
import 'list_snapshot.dart';
import 'settings_service.dart';

/// Keeps the list of the local mode (no account) on the device: [load] puts the saved
/// data back into the in-memory service at app start, [attach] saves it again a moment
/// after every change.
class LocalListStore with WidgetsBindingObserver {
  LocalListStore(this._storage, {Duration? delay})
    : _delay = delay ?? const Duration(milliseconds: 400);

  final SettingsService _storage;
  final Duration _delay;
  static const _key = 'localList';

  StreamSubscription<String>? _subscription;
  Timer? _timer;
  bool _readFailed = false;
  InMemoryListService? _service;
  String? _groupId;

  /// Restores the saved list into [service] and starts saving [groupId] on changes.
  /// Damaged data is dropped. When the saved copy could not be read at all, nothing is
  /// saved this run (an empty list would overwrite it).
  Future<void> attach(InMemoryListService service, String groupId) async {
    switch (await _storage.getString(_key)) {
      case Ok(:final value?):
        Object? json;
        try {
          json = jsonDecode(value);
        } catch (_) {}
        final snapshot = ListSnapshot.tryParse(json);
        if (snapshot == null) {
          debugPrint('local list is unreadable, dropped');
        } else {
          service.restore(snapshot);
        }
      case Failure():
        _readFailed = true;
      case Ok():
        break;
    }
    _service = service;
    _groupId = groupId;
    WidgetsFlutterBinding.ensureInitialized().addObserver(this);
    _subscription?.cancel();
    _subscription = service.changes.listen((_) {
      _timer?.cancel();
      _timer = Timer(_delay, () => save(service, groupId));
    });
  }

  /// A change that waits for its timer is written when the app leaves the screen: the
  /// system may end the process right after.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final service = _service;
    final groupId = _groupId;
    if (state == AppLifecycleState.resumed || service == null || groupId == null) {
      return;
    }
    if (_timer?.isActive ?? false) save(service, groupId);
  }

  /// Writes the list now (an empty one removes the saved copy's content).
  Future<void> save(InMemoryListService service, String groupId) async {
    _timer?.cancel();
    if (_readFailed) return;
    final snapshot = service.snapshotOf(groupId);
    final result = await _storage.setString(
      _key,
      jsonEncode(snapshot.toJson()),
    );
    if (result case Failure(:final error)) {
      debugPrint('local list not saved: $error');
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _timer?.cancel();
  }
}
