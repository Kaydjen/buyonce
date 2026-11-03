import '../../core/utils/result.dart';
import '../../domain/models/account.dart';

/// The Google sign-in behind a user. [userId] names the user inside the app; a real
/// service knows only the person holding the phone and ignores it.
abstract interface class AccountService {
  /// The backend id of the signed-in user (null when nobody is), now and when it
  /// changes. A fake service has none.
  String? get signedInUserId;

  Stream<String?> get signedInUserIdChanges;

  Future<Result<Account?>> getAccount(String userId);

  Future<Result<Account>> signIn(String userId);

  Future<Result<void>> signOut(String userId);

  /// Google asks for the password again before a risky action.
  Future<Result<void>> reauthenticate(String userId);

  Future<Result<void>> deleteAccount(String userId);
}
