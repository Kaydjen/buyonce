import 'dart:async';

import '../../core/utils/result.dart';
import '../../domain/models/update_info.dart';
import 'update_service.dart';

/// Fake update source for the UX stage: version 1.1.0 is always "published", the
/// download is ten timed steps, and the first one fails halfway so the failure state
/// can be seen.
class InMemoryUpdateService implements UpdateService {
  InMemoryUpdateService({
    this.progressStep = const Duration(milliseconds: 300),
    this.failFirstDownload = true,
  });

  static const latestVersion = '1.1.0';

  final Duration progressStep;
  bool failFirstDownload;

  @override
  Future<Result<UpdateInfo?>> checkForUpdate(String currentVersion) async => Ok(
    isNewerVersion(latestVersion, currentVersion)
        ? const UpdateInfo(latestVersion)
        : null,
  );

  @override
  Stream<Result<double>> download(UpdateInfo info) {
    late final StreamController<Result<double>> controller;
    Timer? timer;
    var step = 0;
    controller = StreamController<Result<double>>(
      onListen: () {
        timer = Timer.periodic(progressStep, (t) {
          step++;
          if (failFirstDownload && step == 5) {
            failFirstDownload = false;
            controller.add(const Failure('connection lost'));
            t.cancel();
            controller.close();
            return;
          }
          controller.add(Ok(step / 10));
          if (step >= 10) {
            t.cancel();
            controller.close();
          }
        });
      },
      onCancel: () => timer?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<Result<void>> install(UpdateInfo info) async => const Ok(null);
}
