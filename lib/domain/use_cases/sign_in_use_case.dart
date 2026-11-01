import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/result.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../models/account.dart';
import '../models/user_profile.dart';

/// Signs in, and gives a user who has no display name yet the first name of the Google
/// profile (cut to 10 characters). The result of the account repository feeds the user
/// repository, so this is a use case.
class SignInUseCase {
  SignInUseCase(this._accounts, this._users);
  final AccountRepository _accounts;
  final UserRepository _users;

  Future<Result<void>> call(String userId) async {
    final signedIn = await _accounts.signIn(userId);
    if (signedIn case Failure(:final error)) return Failure(error);
    final account = (signedIn as Ok<Account>).value;
    final names = await _users.getNames();
    if (names case Ok(:final value) when !value.containsKey(userId)) {
      final prefill = prefillDisplayName(account.givenName);
      if (prefill != null) return _users.setDisplayName(userId, prefill);
    }
    return const Ok(null);
  }
}

final signInUseCaseProvider = Provider(
  (ref) => SignInUseCase(
    ref.watch(accountRepositoryProvider),
    ref.watch(userRepositoryProvider),
  ),
);
