import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/utils/result.dart';
import '../../domain/models/account.dart';
import 'account_service.dart';

/// Google sign-in through Firebase Auth. Firebase keeps the session between starts.
class FirebaseAccountService implements AccountService {
  FirebaseAccountService({FirebaseAuth? auth, GoogleSignIn? google})
    : _auth = auth ?? FirebaseAuth.instance,
      _google = google ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _google;

  static Account _accountOf(User user) => Account(
    userId: user.uid,
    email: user.email ?? '',
    givenName: (user.displayName ?? '').trim().split(' ').first,
  );

  /// The Google account chooser; its id token becomes a Firebase credential.
  Future<AuthCredential> _credential() async {
    final google = await _google.authenticate();
    return GoogleAuthProvider.credential(
      idToken: google.authentication.idToken,
    );
  }

  AccountError _signInError(Object error) =>
      error is GoogleSignInException &&
          error.code == GoogleSignInExceptionCode.canceled
      ? AccountError.signInCancelled
      : AccountError.signInFailed;

  @override
  Future<Result<Account?>> getAccount(String userId) async {
    final user = _auth.currentUser;
    return Ok(user == null ? null : _accountOf(user));
  }

  @override
  Future<Result<Account>> signIn(String userId) async {
    try {
      final credential = await _auth.signInWithCredential(await _credential());
      final user = credential.user;
      if (user == null) return const Failure(AccountError.signInFailed);
      return Ok(_accountOf(user));
    } catch (error) {
      return Failure(_signInError(error));
    }
  }

  @override
  Future<Result<void>> signOut(String userId) async {
    try {
      await _auth.signOut();
      await _google.signOut();
      return const Ok(null);
    } catch (_) {
      return const Failure(AccountError.signInFailed);
    }
  }

  @override
  Future<Result<void>> reauthenticate(String userId) async {
    final user = _auth.currentUser;
    if (user == null) return const Failure(AccountError.reauthFailed);
    try {
      await user.reauthenticateWithCredential(await _credential());
      return const Ok(null);
    } catch (_) {
      return const Failure(AccountError.reauthFailed);
    }
  }

  @override
  Future<Result<void>> deleteAccount(String userId) async {
    try {
      await _auth.currentUser?.delete();
      await _google.signOut();
      return const Ok(null);
    } catch (_) {
      return const Failure(AccountError.reauthFailed);
    }
  }
}
