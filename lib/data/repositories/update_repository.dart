import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/result.dart';
import '../../domain/models/update_info.dart';
import '../services/service_providers.dart';
import '../services/update_service.dart';

class UpdateRepository {
  UpdateRepository(this._service);
  final UpdateService _service;

  Future<Result<UpdateInfo?>> check(String currentVersion) =>
      _service.checkForUpdate(currentVersion);

  Stream<Result<double>> download(UpdateInfo info) => _service.download(info);

  Future<Result<void>> install(UpdateInfo info) => _service.install(info);
}

final updateRepositoryProvider = Provider(
  (ref) => UpdateRepository(ref.watch(updateServiceProvider)),
);
