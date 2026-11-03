import 'dart:async';

import 'package:buyonce/data/services/firebase_push_service.dart';
import 'package:buyonce/data/services/push_service.dart';
import 'package:buyonce/data/services/service_providers.dart';
import 'package:buyonce/presentation/view_models/groups/groups_view_model.dart';
import 'package:buyonce/presentation/view_models/session/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Push implements PushService {
  final taps = StreamController<String>();
  @override
  Stream<String> get openedGroupIds => taps.stream;
  @override
  Future<void> register(String userId) async {}
  @override
  Future<void> unregister(String userId) async {}
}

void main() {
  test('groupIdOf reads the group from the push data', () {
    expect(FirebasePushService.groupIdOf({'groupId': 'g1'}), 'g1');
    expect(FirebasePushService.groupIdOf({'groupId': ''}), isNull);
    expect(FirebasePushService.groupIdOf({'groupId': 5}), isNull);
    expect(FirebasePushService.groupIdOf({'kind': 'bought'}), isNull);
  });

  test('a tap on a push selects its group', () async {
    final push = _Push();
    final container = ProviderContainer(
      overrides: [realPushServiceProvider.overrideWithValue(push)],
    );
    addTearDown(container.dispose);
    addTearDown(push.taps.close);
    container.listen(pushOpenProvider, (_, _) {});

    push.taps.add('g2');
    await Future<void>.delayed(Duration.zero);
    expect(container.read(selectedGroupIdProvider), 'g2');
  });

  test('a push of a group the user is not in leaves the shown group', () async {
    final push = _Push();
    final container = ProviderContainer(
      overrides: [realPushServiceProvider.overrideWithValue(push)],
    );
    addTearDown(container.dispose);
    addTearDown(push.taps.close);
    container.listen(pushOpenProvider, (_, _) {});
    container.listen(activeGroupIdProvider, (_, _) {});
    await container.read(groupsViewModelProvider.future);
    final before = container.read(activeGroupIdProvider);
    expect(before, isNotNull);

    push.taps.add('somebody-elses-group');
    await Future<void>.delayed(Duration.zero);
    expect(container.read(activeGroupIdProvider), before);
  });

  test('without a push service nothing happens', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(pushOpenProvider, (_, _) {});
  });
}
