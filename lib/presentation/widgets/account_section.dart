import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/result.dart';
import '../../domain/models/account.dart';
import '../../domain/models/user_profile.dart';
import '../../l10n/l10n.dart';
import '../view_models/account/account_view_model.dart';
import '../view_models/session/session.dart';
import '../view_models/users/user_names_view_model.dart';
import 'accent_button.dart';
import 'card_dialog.dart';
import 'groove.dart';
import 'group_dialogs.dart';
import 'sign_in_prompt.dart';
import 'toast.dart';

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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: AccentButton(
              buttonKey: const Key('accountSignIn'),
              onPressed: () => _signIn(context, ref),
              label: context.l10n.signInWithGoogle,
            ),
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
          title: Text(context.l10n.nameHint),
          subtitle: Text(ref.watch(userNameProvider(me)), style: muted),
          onTap: () => _editName(context, ref, me),
        ),
        ListTile(
          key: const Key('accountEmail'),
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.googleAccount),
          subtitle: Text(signedIn.email, style: muted),
        ),
        const Groove(),
        TextButton(
          key: const Key('signOut'),
          style: _flush,
          onPressed: () => _signOut(context, ref),
          child: Text(context.l10n.signOut),
        ),
        const Groove(),
        TextButton(
          key: const Key('deleteAccount'),
          style: _flush,
          onPressed: () => _delete(context, ref, me),
          child: Text(context.l10n.deleteAccount),
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

  Future<void> _editName(BuildContext context, WidgetRef ref, String me) {
    final l10n = context.l10n;
    return showCardDialog<void>(
      context,
      builder: (_) => PromptDialog(
        title: l10n.nameHint,
        hint: l10n.nameHint,
        confirm: l10n.save,
        initial: ref.read(userNameProvider(me)),
        maxLength: maxDisplayNameLength,
        onSubmit: (name) async => switch (await ref
            .read(userNamesProvider.notifier)
            .setName(me, name)) {
          Ok() => null,
          Failure() => l10n.enterNameLength(maxDisplayNameLength),
        },
      ),
    );
  }

  /// Signed out, the app is a personal list; Settings closes to show it.
  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    // The section rebuilds as signed out, so this context may be gone after the await.
    final navigator = Navigator.of(context);
    final result = await ref.read(accountViewModelProvider.notifier).signOut();
    if (result is Ok<void>) {
      navigator.popUntil((route) => route.isFirst);
    } else if (context.mounted) {
      _say(context, context.l10n.failedSignOut);
    }
  }

  /// Settings closes after a sign-in: a new user lands on the name screen, others on
  /// the list with their groups.
  Future<void> _signIn(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    if (await signInWithFeedback(context, ref)) {
      navigator.popUntil((route) => route.isFirst);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String me) async {
    final sure = await confirmAction(
      context,
      title: context.l10n.deleteAccountTitle,
      body: context.l10n.deleteAccountBody,
      confirm: context.l10n.deleteAccount,
      keep: context.l10n.keepAccount,
    );
    if (!sure || !context.mounted) return;
    final navigator = Navigator.of(context);
    final result = await ref
        .read(accountViewModelProvider.notifier)
        .deleteAccount();
    switch (result) {
      case Ok():
        navigator.popUntil((route) => route.isFirst);
      case Failure(error: AccountError.reauthFailed) when context.mounted:
        _say(context, context.l10n.couldntConfirm);
      case Failure() when context.mounted:
        _say(context, context.l10n.failedDeleteAccount);
      case Failure():
    }
  }

  void _say(BuildContext context, String text) => showToast(context, text);
}
