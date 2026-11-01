import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/result.dart';
import '../../domain/models/account.dart';
import '../view_models/account/account_view_model.dart';

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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text("Couldn't sign in"),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () =>
                retry != null ? retry() : signInWithFeedback(context, ref),
          ),
        ),
      );
  }
  return false;
}

/// Groups need an account: says so and offers the sign-in.
Future<void> showSignInRequired(BuildContext context, WidgetRef ref) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('signInRequired'),
      title: const Text('Sign in to use groups'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not now'),
        ),
        TextButton(
          key: const Key('signInRequiredYes'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Sign in'),
        ),
      ],
    ),
  );
  if (yes != true || !context.mounted) return;
  await signInWithFeedback(context, ref);
}
