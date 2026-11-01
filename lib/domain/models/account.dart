/// The sign-in behind a user: a Google account.
class Account {
  const Account({
    required this.userId,
    required this.email,
    required this.givenName,
  });

  final String userId;
  final String email;

  /// First name from the Google profile; the display name is prefilled from it.
  final String givenName;
}

enum AccountError { reauthFailed, signInCancelled, signInFailed }

/// Debug only: what the next fake Google sign-in does.
enum DebugSignInOutcome { success, cancel, error }
