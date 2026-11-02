import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/result.dart';
import '../../domain/models/account.dart';
import '../view_models/account/account_view_model.dart';
import 'card_dialog.dart';
import 'plain_button.dart';
import 'toast.dart';

/// Starts the Google sign-in. A cancel is silent, any other failure says so with Retry.
/// True when the user is signed in.
Future<bool> signInWithFeedback(
  BuildContext context,
  WidgetRef ref, {
  Future<void> Function()? retry,
}) async {
  final result = await ref.read(accountViewModelProvider.notifier).signIn();
  if (result is Ok<void>) return true;
  if (context.mounted &&
      result is Failure<void> &&
      result.error != AccountError.signInCancelled) {
    showToast(
      context,
      "Couldn't sign in",
      actionLabel: 'Retry',
      onAction: () =>
          retry != null ? retry() : signInWithFeedback(context, ref),
    );
  }
  return false;
}

/// Groups need an account: says so and offers the sign-in.
Future<void> showSignInRequired(BuildContext context, WidgetRef ref) async {
  final yes = await showCardDialog<bool>(
    context,
    builder: (context) => CardDialog(
      key: const Key('signInRequired'),
      title: 'Sign in to use groups',
      cancel: PlainButton(
        label: 'Not now',
        onPressed: () => Navigator.of(context).pop(false),
      ),
      confirm: PlainButton(
        key: const Key('signInRequiredYes'),
        raised: true,
        label: 'Sign in',
        onPressed: () => Navigator.of(context).pop(true),
      ),
    ),
  );
  if (yes != true || !context.mounted) return;
  await signInWithFeedback(context, ref);
}
