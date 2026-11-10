import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/result.dart';
import '../../domain/models/group.dart';
import '../../l10n/l10n.dart';
import '../view_models/groups/groups_view_model.dart';
import 'card_dialog.dart';
import 'inset.dart';
import 'plain_button.dart';

/// A one-field dialog. [onSubmit] returns an error text to show under the field, or
/// null when it worked; the dialog closes only then.
class PromptDialog extends StatefulWidget {
  const PromptDialog({
    super.key,
    required this.title,
    required this.hint,
    required this.confirm,
    required this.onSubmit,
    this.initial = '',
    this.capitals = false,
    this.plain = false,
    this.maxLength,
  });

  final String title;
  final String hint;
  final String confirm;
  final String initial;
  final bool capitals;

  /// A code or a key: no capital letter, no suggestions.
  final bool plain;
  final int? maxLength;
  final Future<String?> Function(String text) onSubmit;

  @override
  State<PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<PromptDialog> {
  late final _text = TextEditingController(text: widget.initial);
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _text.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final error = await widget.onSubmit(_text.text);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _error = error;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return CardDialog(
      title: widget.title,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SoftField(
            child: TextField(
              controller: _text,
              autofocus: true,
              maxLength: widget.maxLength,
              textCapitalization: widget.capitals
                  ? TextCapitalization.characters
                  : widget.plain
                  ? TextCapitalization.none
                  : TextCapitalization.sentences,
              autocorrect: !widget.plain,
              enableSuggestions: !widget.plain,
              decoration: InputDecoration(
                hintText: widget.hint,
                counterText: '',
              ),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _submit(),
            ),
          ),
          // A slow connection: the dialog says it is working and cannot be pressed twice.
          if (_busy)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall!
                    .copyWith(color: t.text),
              ),
            ),
        ],
      ),
      cancel: PlainButton(
        label: context.l10n.cancel,
        onPressed: _busy ? null : () => Navigator.of(context).pop(),
      ),
      confirm: PlainButton(
        raised: true,
        label: widget.confirm,
        onPressed: _busy || _text.text.trim().isEmpty ? null : _submit,
      ),
    );
  }
}

/// What the user reads when a group action fails.
String groupErrorText(AppLocalizations l10n, Object error) => switch (error) {
  GroupError.emptyName => l10n.enterName,
  GroupError.unknownCode => l10n.noGroupWithCode,
  GroupError.full => l10n.groupFull,
  GroupError.offline => l10n.noConnection,
  _ => l10n.somethingWrong,
};

Future<void> showCreateGroupDialog(BuildContext context, WidgetRef ref) {
  final l10n = context.l10n;
  return showCardDialog<void>(
    context,
    builder: (_) => PromptDialog(
      title: l10n.newGroup,
      hint: l10n.groupNameHint,
      confirm: l10n.create,
      onSubmit: (name) async => switch (await ref
          .read(groupsViewModelProvider.notifier)
          .create(name)) {
        Ok() => null,
        Failure(:final error) => groupErrorText(l10n, error),
      },
    ),
  );
}

Future<void> showJoinGroupDialog(BuildContext context, WidgetRef ref) {
  final l10n = context.l10n;
  return showCardDialog<void>(
    context,
    builder: (_) => PromptDialog(
      title: l10n.joinGroup,
      hint: l10n.codeHint,
      confirm: l10n.join,
      capitals: true,
      onSubmit: (code) async =>
          switch (await ref.read(groupsViewModelProvider.notifier).join(code)) {
            Ok() => null,
            Failure(:final error) => groupErrorText(l10n, error),
          },
    ),
  );
}

Future<void> showRenameGroupDialog(
  BuildContext context,
  WidgetRef ref,
  Group group,
) {
  final l10n = context.l10n;
  return showCardDialog<void>(
    context,
    builder: (_) => PromptDialog(
      title: l10n.renameGroup,
      hint: l10n.groupNameHint,
      confirm: l10n.rename,
      initial: group.name,
      onSubmit: (name) async => switch (await ref
          .read(groupsViewModelProvider.notifier)
          .rename(group.id, name)) {
        Ok() => null,
        Failure(:final error) => groupErrorText(l10n, error),
      },
    ),
  );
}

/// A confirmation whose buttons say what happens; true when the user confirms.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
  required String keep,
}) async =>
    await showCardDialog<bool>(
      context,
      builder: (context) => CardDialog(
        title: title,
        content: Text(
          body,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        cancel: PlainButton(
          label: keep,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        confirm: PlainButton(
          raised: true,
          label: confirm,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ),
    ) ??
    false;
