import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/account.dart';
import '../view_models/account/account_view_model.dart';
import '../../core/theme/app_tokens.dart';
import '../widgets/accent_button.dart';
import '../widgets/plain_button.dart';
import '../widgets/sign_in_prompt.dart';
import '../widgets/card_sheet.dart';

/// Shown at the start until the user signs in or continues without an account (local
/// mode: the personal list only). A cancelled sign-in returns here silently, a failed
/// one says so with Retry.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _busy = false;

  Future<void> _signIn() async {
    if (_busy) return;
    setState(() => _busy = true);
    await signInWithFeedback(context, ref, retry: _signIn);
    // On success the gate has already replaced this screen.
    if (mounted) setState(() => _busy = false);
  }

  /// Debug only: choose what the next fake sign-in does.
  Future<void> _debugOutcome() async {
    final vm = ref.read(accountViewModelProvider.notifier);
    final picked = await showCardSheet<DebugSignInOutcome>(
      context,
      builder: (context) => SheetCard(
        children: [
          for (final o in DebugSignInOutcome.values)
            ListTile(
              key: Key('outcome-${o.name}'),
              title: Text(switch (o) {
                DebugSignInOutcome.success => 'Success',
                DebugSignInOutcome.cancel => 'Cancel',
                DebugSignInOutcome.error => 'Error',
              }),
              trailing: o == vm.debugNextSignIn
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(context).pop(o),
            ),
        ],
      ),
    );
    if (picked != null) vm.debugNextSignIn = picked;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _busy
            ? const CircularProgressIndicator(key: Key('signInProgress'))
            : ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.tokens.gutter,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AccentButton(
                        buttonKey: const Key('signIn'),
                        onPressed: _signIn,
                        onLongPress: kDebugMode ? _debugOutcome : null,
                        label: 'Sign in with Google',
                      ),
                      const SizedBox(height: 20),
                      PlainButton(
                        key: const Key('continueLocal'),
                        onPressed: () =>
                            ref.read(localModeProvider.notifier).set(true),
                        label: 'Continue without account',
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
