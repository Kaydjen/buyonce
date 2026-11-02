import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// A short message at the bottom, one at a time: a soft raised pill in the page colour,
/// not the standard dark bar. An action ("Undo") sits inside the pill.
void showToast(
  BuildContext context,
  String text, {
  Duration duration = const Duration(seconds: 4),
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        // The pill draws itself, with its own shadow.
        backgroundColor: const Color(0x00000000),
        elevation: 0,
        clipBehavior: Clip.none,
        padding: EdgeInsets.zero,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          context.tokens.gutter,
          0,
          context.tokens.gutter,
          10,
        ),
        duration: duration,
        content: _Toast(
          text: text,
          actionLabel: actionLabel,
          onAction: onAction == null
              ? null
              : () {
                  messenger.hideCurrentSnackBar();
                  onAction();
                },
        ),
      ),
    );
}

class _Toast extends StatelessWidget {
  const _Toast({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(t.radiusButton),
        boxShadow: t.depth > 0 ? t.raised(0.6) : null,
        border: t.depth == 0
            ? Border.all(color: t.line, width: t.lineWidth)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  text,
                  style: theme.textTheme.bodyMedium!.copyWith(color: t.text),
                ),
              ),
            ),
            if (actionLabel != null)
              TextButton(
                onPressed: onAction,
                child: Text(
                  actionLabel!,
                  style: t.weighted(
                    theme.textTheme.labelLarge!.copyWith(color: t.text),
                    t.titleWeight,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
