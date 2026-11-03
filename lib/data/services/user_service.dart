import '../../core/utils/result.dart';
import '../../domain/models/user_profile.dart';

/// Storage of display names. A name is public to every signed-in user, but only by id:
/// there is no way to list the users (the Firestore rules allow `get` only), so a read
/// always says whose names it wants.
abstract class UserService {
  /// Names of [userIds]; a user without a profile is missing from the map.
  Future<Result<Map<String, String>>> getNames(Set<String> userIds);

  Future<Result<void>> putProfile(UserProfile profile);

  Future<Result<void>> deleteProfile(String userId);
}
