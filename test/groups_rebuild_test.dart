import 'dart:async';

import 'package:buyonce/core/utils/result.dart';
import 'package:buyonce/data/services/in_memory_group_service.dart';
import 'package:buyonce/data/services/service_providers.dart';
import 'package:buyonce/domain/models/group.dart';
import 'package:buyonce/presentation/view_models/groups/groups_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts the live `watchGroups` listeners and holds the first `getGroups` answer.
class _Service extends InMemoryGroupService {
  _Service() : super(seed: true);
  int live = 0;
  final gate = Completer<void>();
  bool gateUsed = false;

  @override
  Future<Result<List<Group>>> getGroups(String userId) async {
    if (!gateUsed) {
      gateUsed = true;
      await gate.future;
    }
    return super.getGroups(userId);
  }

  @override
  Stream<Result<List<Group>>> watchGroups(String userId) {
    late final StreamController<Result<List<Group>>> c;
    StreamSubscription<Result<List<Group>>>? inner;
    c = StreamController(
      onListen: () {
        live++;
        inner = super.watchGroups(userId).listen(c.add);
      },
      onCancel: () {
        live--;
        return inner?.cancel();
      },
    );
    return c.stream;
  }
}

void main() {
  test('a build superseded while loading leaves no listener behind', () async {
    final service = _Service();
    final container = ProviderContainer(
      overrides: [inMemoryGroupServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    container.listen(groupsViewModelProvider, (_, _) {});

    // The first build waits for its groups; meanwhile the provider is built again
    // (as it is when the account answers).
    await Future<void>.delayed(Duration.zero);
    container.invalidate(groupsViewModelProvider);
    await Future<void>.delayed(Duration.zero);
    service.gate.complete();
    await container.read(groupsViewModelProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(service.live, 1);
  });
}
