import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/result.dart';
import '../../domain/models/group.dart';
import '../../core/theme/app_tokens.dart';
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
    this.maxLength,
  });

  final String title;
  final String hint;
  final String confirm;
  final String initial;
  final bool capitals;
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
                  : TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: widget.hint,
                counterText: '',
              ),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _submit(),
            ),
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
        label: 'Cancel',
        onPressed: () => Navigator.of(context).pop(),
      ),
      confirm: PlainButton(
        raised: true,
        label: widget.confirm,
        onPressed: _text.text.trim().isEmpty ? null : _submit,
      ),
    );
  }
}

Future<void> showCreateGroupDialog(BuildContext context, WidgetRef ref) =>
    showCardDialog<void>(
      context,
      builder: (_) => PromptDialog(
        title: 'New group',
        hint: 'Group name',
        confirm: 'Create',
        onSubmit: (name) async => switch (await ref
            .read(groupsViewModelProvider.notifier)
            .create(name)) {
          Ok() => null,
          Failure() => 'Enter a name',
        },
      ),
    );

Future<void> showJoinGroupDialog(BuildContext context, WidgetRef ref) =>
    showCardDialog<void>(
      context,
      builder: (_) => PromptDialog(
        title: 'Join group',
        hint: 'Code',
        confirm: 'Join',
        capitals: true,
        onSubmit: (code) async => switch (await ref
            .read(groupsViewModelProvider.notifier)
            .join(code)) {
          Ok() => null,
          Failure() => 'No group with this code',
        },
      ),
    );

Future<void> showRenameGroupDialog(
  BuildContext context,
  WidgetRef ref,
  Group group,
) => showCardDialog<void>(
  context,
  builder: (_) => PromptDialog(
    title: 'Rename group',
    hint: 'Group name',
    confirm: 'Rename',
    initial: group.name,
    onSubmit: (name) async => switch (await ref
        .read(groupsViewModelProvider.notifier)
        .rename(group.id, name)) {
      Ok() => null,
      Failure() => 'Enter a name',
    },
  ),
);

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
