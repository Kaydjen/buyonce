import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/result.dart';
import '../../domain/models/account.dart';
import '../../domain/models/user_profile.dart';
import '../view_models/account/account_view_model.dart';
import '../view_models/session/session.dart';
import '../view_models/users/user_names_view_model.dart';
import 'group_dialogs.dart';
import 'sign_in_prompt.dart';

/// Settings > Account: the display name other members see, the Google sign-in, sign
/// out and delete account.
class AccountSection extends ConsumerWidget {
  const AccountSection({super.key});

  /// Text buttons start at the same edge as the tiles above them.
  static final _flush = TextButton.styleFrom(
    padding: EdgeInsets.zero,
    minimumSize: const Size(0, 48),
    alignment: Alignment.centerLeft,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountViewModelProvider);
    final muted = TextStyle(color: context.tokens.muted);
    final me = ref.watch(currentUserIdProvider);
    if (!account.hasValue) return const SizedBox.shrink();
    final signedIn = account.requireValue;
    if (signedIn == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton(
            key: const Key('accountSignIn'),
            onPressed: () => _signIn(context, ref),
            child: const Text('Sign in with Google'),
          ),
          if (kDebugMode) _debugLoginButton(context, ref),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          key: const Key('accountName'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Name'),
          subtitle: Text(ref.watch(userNameProvider(me)), style: muted),
          onTap: () => _editName(context, ref, me),
        ),
        ListTile(
          key: const Key('accountEmail'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Google account'),
          subtitle: Text(signedIn.email, style: muted),
        ),
        TextButton(
          key: const Key('signOut'),
          style: _flush,
          onPressed: () => _signOut(context, ref),
          child: const Text('Sign out'),
        ),
        TextButton(
          key: const Key('deleteAccount'),
          style: _flush,
          onPressed: () => _delete(context, ref, me),
          child: const Text('Delete account'),
        ),
        if (kDebugMode) _debugLoginButton(context, ref),
      ],
    );
  }

  /// Debug only: the fake users start signed in, so this is the way to the login screen.
  Widget _debugLoginButton(BuildContext context, WidgetRef ref) => TextButton(
    key: const Key('debugShowLogin'),
    style: _flush,
    onPressed: () async {
      await ref.read(accountViewModelProvider.notifier).debugShowLogin();
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    },
    child: const Text('Debug: show login screen'),
  );

  Future<void> _editName(BuildContext context, WidgetRef ref, String me) =>
      showDialog<void>(
        context: context,
        builder: (_) => PromptDialog(
          title: 'Name',
          hint: 'Name',
          confirm: 'Save',
          initial: ref.read(userNameProvider(me)),
          maxLength: maxDisplayNameLength,
          onSubmit: (name) async => switch (await ref
              .read(userNamesProvider.notifier)
              .setName(me, name)) {
            Ok() => null,
            Failure() => 'Enter 1-10 characters',
          },
        ),
      );

  /// Signed out, the app is a personal list; Settings closes to show it.
  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(accountViewModelProvider.notifier).signOut();
    if (!context.mounted) return;
    if (result is Ok<void>) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      _say(context, 'Failed to sign out');
    }
  }

  /// Settings closes after a sign-in: a new user lands on the name screen, others on
  /// the list with their groups.
  Future<void> _signIn(BuildContext context, WidgetRef ref) async {
    if (await signInWithFeedback(context, ref) && context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String me) async {
    final sure = await confirmAction(
      context,
      title: 'Delete account?',
      body: 'You leave all groups and your data is deleted. This cannot be undone.',
      confirm: 'Delete account',
      keep: 'Keep account',
    );
    if (!sure || !context.mounted) return;
    final result = await ref
        .read(accountViewModelProvider.notifier)
        .deleteAccount();
    if (!context.mounted) return;
    switch (result) {
      case Ok():
        Navigator.of(context).popUntil((route) => route.isFirst);
      case Failure(error: AccountError.reauthFailed):
        _say(context, "Couldn't confirm. Try again.");
      case Failure():
        _say(context, 'Failed to delete the account');
    }
  }

  void _say(BuildContext context, String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
