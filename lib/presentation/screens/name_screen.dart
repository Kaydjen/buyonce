import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/result.dart';
import '../../domain/models/user_profile.dart';
import '../view_models/account/account_view_model.dart';
import '../view_models/session/session.dart';
import '../view_models/users/user_names_view_model.dart';
import '../widgets/accent_button.dart';
import '../widgets/inset.dart';
import '../widgets/toast.dart';

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
    _text = TextEditingController();
    // The prefilled name arrives once the names are read; what the user typed stays.
    ref.listenManual(userNamesProvider, (_, names) {
      final prefill = names.value?[ref.read(currentUserIdProvider)];
      if (prefill != null && _text.text.isEmpty) {
        setState(() => _text.text = prefill);
      }
    }, fireImmediately: true);
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
        showToast(context, 'Enter 1-10 characters');
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
              SoftField(
                child: TextField(
                  key: const Key('nameField'),
                  controller: _text,
                  autofocus: true,
                  maxLength: maxDisplayNameLength,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Name',
                    counterText: '',
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: AccentButton(
                  buttonKey: const Key('nameContinue'),
                  onPressed: _valid && !_busy ? _submit : null,
                  label: 'Continue',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
