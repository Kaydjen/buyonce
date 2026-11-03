import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/result.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../models/account.dart';
import '../models/user_profile.dart';

/// Signs in, and gives a user who has no display name yet the first name of the Google
/// profile (cut to 10 characters). The result of the account repository feeds the user
/// repository, so this is a use case. The name belongs to the backend id that comes
/// back with the account. Result: true when the user had no name before (the name
/// screen is shown once).
class SignInUseCase {
  SignInUseCase(this._accounts, this._users);
  final AccountRepository _accounts;
  final UserRepository _users;

  Future<Result<bool>> call(String slot) async {
    final signedIn = await _accounts.signIn(slot);
    if (signedIn case Failure(:final error)) return Failure(error);
    final account = (signedIn as Ok<Account>).value;
    final userId = account.userId;
    final names = await _users.getNames({userId});
    if (names case Ok(:final value) when value.isEmpty) {
      final prefill = prefillDisplayName(account.givenName);
      if (prefill != null) {
        final saved = await _users.setDisplayName(userId, prefill);
        if (saved case Failure(:final error)) return Failure(error);
      }
      return const Ok(true);
    }
    return const Ok(false);
  }
}

final signInUseCaseProvider = Provider(
  (ref) => SignInUseCase(
    ref.watch(accountRepositoryProvider),
    ref.watch(userRepositoryProvider),
  ),
);
