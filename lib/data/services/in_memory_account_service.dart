import 'package:flutter/foundation.dart';

import '../../core/utils/result.dart';
import '../../domain/models/account.dart';
import 'account_service.dart';

/// Fake Google sign-in for the UX stage; Firebase Auth replaces it.
class InMemoryAccountService implements AccountService {
  /// Debug builds start signed in as the two fake users; otherwise nobody is signed in.
  InMemoryAccountService({bool? seed}) {
    if (seed ?? kDebugMode) {
      for (final id in _givenNames.keys) {
        _accounts[id] = _accountOf(id);
      }
    }
  }

  static const _givenNames = {'me': 'Alexander', 'partner': 'Anna'};

  static Account _accountOf(String userId) => Account(
    userId: userId,
    email: '$userId@example.com',
    givenName: _givenNames[userId] ?? 'Guest',
  );

  /// Tests set this to see the failed re-authentication.
  bool failReauth = false;

  final Map<String, Account> _accounts = {};

  @override
  Future<Result<Account?>> getAccount(String userId) async =>
      Ok(_accounts[userId]);

  /// What the next [signIn] does; it falls back to success after one use.
  DebugSignInOutcome nextSignIn = DebugSignInOutcome.success;

  /// What the Google account chooser would return.
  @override
  Future<Result<Account>> signIn(String userId) async {
    // A short wait so the progress state is visible.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final outcome = nextSignIn;
    nextSignIn = DebugSignInOutcome.success;
    switch (outcome) {
      case DebugSignInOutcome.cancel:
        return const Failure(AccountError.signInCancelled);
      case DebugSignInOutcome.error:
        return const Failure(AccountError.signInFailed);
      case DebugSignInOutcome.success:
        break;
    }
    final account = _accountOf(userId);
    _accounts[userId] = account;
    return Ok(account);
  }

  @override
  Future<Result<void>> signOut(String userId) async {
    _accounts.remove(userId);
    return const Ok(null);
  }

  /// Google asks for the password again before a risky action.
  @override
  Future<Result<void>> reauthenticate(String userId) async =>
      failReauth ? const Failure(AccountError.reauthFailed) : const Ok(null);

  @override
  Future<Result<void>> deleteAccount(String userId) => signOut(userId);
}
