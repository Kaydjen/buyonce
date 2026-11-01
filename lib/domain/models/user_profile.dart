/// What the other members of a group see instead of an account id.
const maxDisplayNameLength = 10;

/// Shown for a user whose profile has no name yet.
const unnamedUser = 'Member';

/// The name without surrounding spaces, or null when it is not 1-10 characters
/// (code points, not bytes: "Мама" is 4).
String? cleanDisplayName(String raw) {
  final name = raw.trim();
  final length = name.runes.length;
  return length >= 1 && length <= maxDisplayNameLength ? name : null;
}

class UserProfile {
  const UserProfile({required this.id, required this.displayName});
  final String id;
  final String displayName;
}

enum UserError { invalidName }

/// A display name made from a Google first name: cut to 10 characters, or null when
/// nothing is left.
String? prefillDisplayName(String givenName) {
  final cut = String.fromCharCodes(
    givenName.trim().runes.take(maxDisplayNameLength),
  );
  return cleanDisplayName(cut);
}
