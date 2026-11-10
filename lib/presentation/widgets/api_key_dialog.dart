import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/result.dart';
import '../../data/repositories/gemini_key_repository.dart';
import '../../l10n/l10n.dart';
import '../view_models/settings/gemini_key_view_model.dart';
import 'card_dialog.dart';
import 'group_dialogs.dart';

/// The paste dialog of the Gemini API key; the key is saved when it closes with Save.
Future<void> showApiKeyDialog(BuildContext context, WidgetRef ref) {
  final l10n = context.l10n;
  return showCardDialog<void>(
    context,
    builder: (_) => PromptDialog(
      title: l10n.apiKey,
      hint: l10n.apiKey,
      confirm: l10n.save,
      plain: true,
      onSubmit: (text) async =>
          switch (await ref.read(geminiKeyProvider.notifier).save(text)) {
            Ok() => null,
            Failure(error: GeminiKeyError.invalid) => l10n.invalidApiKey,
            Failure() => l10n.somethingWrong,
          },
    ),
  );
}
