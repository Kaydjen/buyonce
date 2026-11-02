import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'panel.dart';
import 'plain_button.dart';

/// A dialog as a floating raised card on the same veil as the sheets: a centred title,
/// the content, and a row of buttons ([cancel] flat, [confirm] raised).
Future<T?> showCardDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showDialog<T>(
  context: context,
  barrierColor: context.tokens.background.withValues(alpha: 0.8),
  builder: builder,
);

class CardDialog extends StatelessWidget {
  const CardDialog({
    super.key,
    required this.title,
    this.content,
    required this.cancel,
    required this.confirm,
  });

  final String title;
  final Widget? content;
  final PlainButton cancel;
  final PlainButton confirm;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Dialog(
      backgroundColor: const Color(0x00000000),
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: t.gutter, vertical: 24),
      child: Panel(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.capsTitles ? title.toUpperCase() : title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium!
                    .copyWith(color: t.muted, letterSpacing: t.captionSpacing),
              ),
              if (content != null) ...[const SizedBox(height: 16), content!],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: cancel),
                  const SizedBox(width: 12),
                  Expanded(child: confirm),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
