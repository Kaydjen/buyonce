import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'accent_dot.dart';

/// The one accent button of a screen (Send, Notify, Add): every restyle of the accent
/// happens here and in the style's tokens.
class AccentButton extends StatelessWidget {
  const AccentButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.onLongPress,
    this.buttonKey,
    this.done = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final Key? buttonKey;

  /// The action has just happened: a check takes the place of the dot.
  final bool done;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radiusButton),
          boxShadow: t.depth > 0 ? t.raised(0.7) : null,
        ),
        child: FilledButton(
          key: buttonKey,
          style: FilledButton.styleFrom(
            backgroundColor: t.depth > 0 ? t.surface : t.tint,
            foregroundColor: t.accentAsText ? t.ink : t.text,
            side: t.depth > 0
                ? null
                : BorderSide(color: t.ink, width: t.lineWidth),
            minimumSize: const Size(0, 56),
            padding: const EdgeInsets.symmetric(horizontal: 28),
          ),
          onPressed: onPressed,
          onLongPress: onLongPress,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (done) ...[
                  Icon(Icons.check, size: 20, color: t.text),
                  const SizedBox(width: 8),
                ] else if (!t.accentAsText) ...[
                  const AccentDot(size: 9),
                  const SizedBox(width: 10),
                ],
                Text(
                  label,
                  style: t.controlStyle(
                    Theme.of(context).textTheme.titleMedium!
                        .copyWith(color: t.accentAsText ? t.ink : t.text),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
