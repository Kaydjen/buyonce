import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/result.dart';
import '../../domain/models/user_profile.dart';
import '../view_models/account/account_view_model.dart';
import '../view_models/session/session.dart';
import '../view_models/users/user_names_view_model.dart';

/// Shown once after the first sign-in: the name other members see, prefilled from the
/// Google profile.
class NameScreen extends ConsumerStatefulWidget {
  const NameScreen({super.key});

  @override
  ConsumerState<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends ConsumerState<NameScreen> {
  late final TextEditingController _text;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final me = ref.read(currentUserIdProvider);
    final name = ref.read(userNameProvider(me));
    _text = TextEditingController(text: name == unnamedUser ? '' : name);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _valid => cleanDisplayName(_text.text) != null;

  Future<void> _submit() async {
    if (_busy || !_valid) return;
    setState(() => _busy = true);
    final me = ref.read(currentUserIdProvider);
    final result = await ref
        .read(userNamesProvider.notifier)
        .setName(me, _text.text);
    if (!mounted) return;
    switch (result) {
      case Ok():
        ref.read(namePendingProvider.notifier).set(false);
      case Failure():
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Enter 1-10 characters')),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.tokens.gutter),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('nameField'),
                controller: _text,
                autofocus: true,
                maxLength: maxDisplayNameLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Name'),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('nameContinue'),
                onPressed: _valid && !_busy ? _submit : null,
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
