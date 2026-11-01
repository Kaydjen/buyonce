import '../../core/utils/result.dart';
import '../../domain/models/update_info.dart';

/// Where new versions come from. The fake stands in until a version file and an APK
/// are hosted (publishing stage).
abstract class UpdateService {
  /// The newer version than [currentVersion], or null when this is the latest.
  Future<Result<UpdateInfo?>> checkForUpdate(String currentVersion);

  /// Progress 0..1; ends after 1, or after a [Failure].
  Stream<Result<double>> download(UpdateInfo info);

  /// Hands the downloaded file to the system installer.
  Future<Result<void>> install(UpdateInfo info);
}
