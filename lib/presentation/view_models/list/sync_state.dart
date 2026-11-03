import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Counts the writes that were shown and then refused (or could not be made). The list
/// screen watches it and shows a toast per change; the list itself stays as it is.
class WriteFailures extends Notifier<int> {
  @override
  int build() => 0;

  void report() => state++;
}

final writeFailuresProvider = NotifierProvider<WriteFailures, int>(
  WriteFailures.new,
);

/// True while the app cannot reach the server; the offline sign shows only then.
class Offline extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool offline) => state = offline;
}

final offlineProvider = NotifierProvider<Offline, bool>(Offline.new);
