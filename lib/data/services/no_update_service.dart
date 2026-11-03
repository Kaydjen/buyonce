import '../../core/utils/result.dart';
import '../../domain/models/update_info.dart';
import 'update_service.dart';

/// Release builds until hosted updates exist: there is never a newer version.
class NoUpdateService implements UpdateService {
  @override
  Future<Result<UpdateInfo?>> checkForUpdate(String currentVersion) async =>
      const Ok(null);

  @override
  Stream<Result<double>> download(UpdateInfo info) => const Stream.empty();

  @override
  Future<Result<void>> install(UpdateInfo info) async => const Ok(null);
}
