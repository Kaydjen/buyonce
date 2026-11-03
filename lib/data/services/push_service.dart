/// The phone's address for push messages. The server (the Worker) reads the saved token
/// to notify a member; it never takes a token from a client request.
abstract interface class PushService {
  /// Asks for the notification permission (Android 13+), saves this phone's token for
  /// [userId] and keeps it fresh when the system replaces it. Calling it again for the
  /// same user is harmless; a different user replaces the first.
  Future<void> register(String userId);

  /// Removes the saved token of [userId] and stops following the system. Must run while
  /// that user is still signed in (the rules allow only the owner).
  Future<void> unregister(String userId);

  /// Ids of the groups whose push the user tapped: the one that started the app and
  /// the ones tapped while the app was in the background.
  Stream<String> get openedGroupIds;
}
