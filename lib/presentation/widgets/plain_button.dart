import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// A quiet pill button with a text label: a flat tint plate, or a raised pill when
/// [raised] (the confirming one of a pair). The accent stays with [AccentButton].
class PlainButton extends StatelessWidget {
  const PlainButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.raised = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool raised;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final soft = raised && t.depth > 0;
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radiusButton),
          boxShadow: soft ? t.raised(0.5) : null,
        ),
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            backgroundColor: soft || raised ? t.surface : t.tint,
            foregroundColor: raised ? t.text : t.muted,
            minimumSize: const Size(0, 52),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(t.radiusButton),
            ),
          ),
          child: Text(
            label,
            style: t.controlStyle(
              Theme.of(context).textTheme.titleMedium!
                  .copyWith(color: raised ? t.text : t.muted),
            ),
          ),
        ),
      ),
    );
  }
}
