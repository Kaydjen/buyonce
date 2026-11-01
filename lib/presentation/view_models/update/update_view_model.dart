import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_info.dart';
import '../../../core/utils/result.dart';
import '../../../data/repositories/update_repository.dart';
import '../../../domain/models/update_info.dart';

enum UpdateStatus { upToDate, available, downloading, failed, ready }

class UpdateState {
  const UpdateState({
    this.status = UpdateStatus.upToDate,
    this.currentVersion = appVersion,
    this.info,
    this.progress = 0,
  });

  final UpdateStatus status;
  final String currentVersion;

  /// The version on offer; null when up to date.
  final UpdateInfo? info;

  /// 0..1 while downloading.
  final double progress;

  /// Something newer is known, in any stage up to the install: the menu shows a dot.
  bool get hasUpdate => status != UpdateStatus.upToDate;
}

/// When the app has opened, how long until it asks for a newer version.
final updateCheckDelayProvider = Provider<Duration>(
  (_) => const Duration(seconds: 2),
);

/// The update check and the download, as the Settings row shows them.
class UpdateViewModel extends Notifier<UpdateState> {
  StreamSubscription<Result<double>>? _download;

  @override
  UpdateState build() {
    final timer = Timer(ref.read(updateCheckDelayProvider), _check);
    ref.onDispose(() {
      timer.cancel();
      _download?.cancel();
    });
    return const UpdateState();
  }

  Future<void> _check() async {
    final result = await ref
        .read(updateRepositoryProvider)
        .check(state.currentVersion);
    if (!ref.mounted) return;
    if (result case Ok(:final value) when value != null) {
      state = UpdateState(
        status: UpdateStatus.available,
        currentVersion: state.currentVersion,
        info: value,
      );
    }
  }

  /// Starts the download; also the retry after a failure.
  void download() {
    final info = state.info;
    if (info == null || state.status == UpdateStatus.downloading) return;
    _set(UpdateStatus.downloading, progress: 0);
    _download?.cancel();
    _download = ref.read(updateRepositoryProvider).download(info).listen((r) {
      switch (r) {
        case Ok(:final value):
          _set(
            value >= 1 ? UpdateStatus.ready : UpdateStatus.downloading,
            progress: value,
          );
        case Failure():
          _set(UpdateStatus.failed);
      }
    });
  }

  /// The system installer takes over; here the new version simply becomes current.
  Future<void> install() async {
    final info = state.info;
    if (info == null || state.status != UpdateStatus.ready) return;
    final result = await ref.read(updateRepositoryProvider).install(info);
    if (!ref.mounted) return;
    if (result is Ok<void>) {
      state = UpdateState(currentVersion: info.version);
    } else {
      _set(UpdateStatus.failed);
    }
  }

  void _set(UpdateStatus status, {double? progress}) => state = UpdateState(
    status: status,
    currentVersion: state.currentVersion,
    info: state.info,
    progress: progress ?? state.progress,
  );
}

final updateViewModelProvider = NotifierProvider<UpdateViewModel, UpdateState>(
  UpdateViewModel.new,
);
