import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/result.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../domain/models/account.dart';
import '../../../domain/use_cases/delete_account_use_case.dart';
import '../../../domain/use_cases/sign_in_use_case.dart';
import '../session/session.dart';

/// The sign-in of the current user; null when signed out.
class AccountViewModel extends AsyncNotifier<Account?> {
  @override
  Future<Account?> build() => _load(ref.watch(userSlotProvider));

  Future<Account?> _load(String userId) async =>
      switch (await ref.read(accountRepositoryProvider).getAccount(userId)) {
        Ok(:final value) => value,
        Failure(:final error) => throw error,
      };

  /// The account calls name the fake slot; the backend id comes back in the account.
  String get _userId => ref.read(userSlotProvider);

  /// A user who had no name before gets the name screen once, prefilled by the sign-in.
  Future<Result<void>> signIn() async {
    final userId = _userId;
    final result = await ref.read(signInUseCaseProvider)(userId);
    if (result case Ok(:final value)) {
      // The names reload themselves when the account state below changes.
      ref.read(namePendingProvider.notifier).set(value);
      state = AsyncData(await _load(userId));
    }
    return result;
  }

  /// Local data stays on the phone; the account is only disconnected.
  Future<Result<void>> signOut() async {
    final result = await ref.read(accountRepositoryProvider).signOut(_userId);
    if (result is Ok<void>) {
      ref.read(namePendingProvider.notifier).set(false);
      // Signed out the app keeps working as a personal list.
      ref.read(localModeProvider.notifier).set(true);
      state = AsyncData(await _load(_userId));
    }
    return result;
  }

  /// Debug only: signs out and shows the login screen instead of the local list.
  Future<void> debugShowLogin() async {
    await signOut();
    ref.read(localModeProvider.notifier).set(false);
  }

  DebugSignInOutcome get debugNextSignIn =>
      ref.read(accountRepositoryProvider).debugNextSignIn;

  set debugNextSignIn(DebugSignInOutcome outcome) =>
      ref.read(accountRepositoryProvider).debugNextSignIn = outcome;

  /// Fails with [AccountError.reauthFailed] when Google does not confirm. On success the groups
  /// and names are read again: the user is left with an empty personal list.
  Future<Result<void>> deleteAccount() async {
    final result = await ref.read(deleteAccountUseCaseProvider)(
      _userId,
      ref.read(currentUserIdProvider),
    );
    if (result is Ok<void>) {
      ref.read(localModeProvider.notifier).set(true);
      ref.read(selectedGroupIdProvider.notifier).select(null);
      state = AsyncData(await _load(_userId));
    }
    return result;
  }
}

/// True between the first sign-in and the user confirming the name.
class NamePending extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool pending) => state = pending;
}

final namePendingProvider = NotifierProvider<NamePending, bool>(
  NamePending.new,
);

/// The user chose to use the app without an account (or signed out): the login screen
/// is not shown again. Kept in memory only for now.
class LocalMode extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool local) => state = local;
}

final localModeProvider = NotifierProvider<LocalMode, bool>(LocalMode.new);

final accountViewModelProvider =
    AsyncNotifierProvider<AccountViewModel, Account?>(AccountViewModel.new);
