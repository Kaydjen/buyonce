import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/group.dart';
import 'group_service.dart';
import 'list_service.dart';
import 'service_providers.dart';
import 'user_service.dart';

/// Which fake user the phone acts as: `me` (the person holding the phone) or `partner`
/// (debug switch). Only the account calls use it; everything else uses
/// [currentUserIdProvider].
class UserSlot extends Notifier<String> {
  @override
  String build() => groupUserIds.first;

  void select(String slot) => state = slot;
}

final userSlotProvider = NotifierProvider<UserSlot, String>(UserSlot.new);

/// The backend id (Firebase uid) of the person holding the phone while signed in for
/// real; null when signed out or when the app has no real account service (tests).
class RealUserId extends Notifier<String?> {
  @override
  String? build() {
    final service = ref.watch(realAccountServiceProvider);
    if (service == null) return null;
    final subscription = service.signedInUserIdChanges.listen(
      (id) => state = id,
    );
    ref.onDispose(subscription.cancel);
    return service.signedInUserId;
  }
}

final realUserIdProvider = NotifierProvider<RealUserId, String?>(
  RealUserId.new,
);

/// Keeps this phone's push token saved for the signed-in user (watched by the app root).
/// Sign-out removes it first, in [AccountRepository].
final pushRegistrationProvider = Provider<void>((ref) {
  final push = ref.watch(realPushServiceProvider);
  final uid = ref.watch(realUserIdProvider);
  if (push != null && uid != null) push.register(uid);
});

/// The user whose data the app shows: the real uid while the person holding the phone
/// is signed in for real, else the fake slot. Data of a real uid lives on Firestore,
/// data of a fake id in memory.
final currentUserIdProvider = Provider<String>((ref) {
  final slot = ref.watch(userSlotProvider);
  if (slot != groupUserIds.first) return slot;
  return ref.watch(realUserIdProvider) ?? slot;
});

bool _isReal(Ref ref) {
  final real = ref.watch(realUserIdProvider);
  return real != null && ref.watch(currentUserIdProvider) == real;
}

/// Groups on Firestore for the real user, in memory for the fake ones.
final groupServiceProvider = Provider<GroupService>((ref) {
  final real = ref.watch(realGroupServiceProvider);
  return real != null && _isReal(ref)
      ? real
      : ref.watch(inMemoryGroupServiceProvider);
});

/// Lists on Firestore for the real user, in memory for the fake ones.
final listServiceProvider = Provider<ListService>((ref) {
  final real = ref.watch(realListServiceProvider);
  return real != null && _isReal(ref)
      ? real
      : ref.watch(inMemoryListServiceProvider);
});

/// Names on Firestore for the real user, in memory for the fake ones.
final userServiceProvider = Provider<UserService>((ref) {
  final real = ref.watch(realUserServiceProvider);
  return real != null && _isReal(ref)
      ? real
      : ref.watch(inMemoryUserServiceProvider);
});
