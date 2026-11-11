import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../l10n/l10n.dart';

/// The small card that floats above a product row after a long press: rename, amount and delete,
/// three icons (each has a label for screen readers and a tooltip).
class RowMenuCard extends StatelessWidget {
  const RowMenuCard({
    super.key,
    required this.onRename,
    required this.onAmount,
    required this.onDelete,
  });

  final VoidCallback onRename;
  final VoidCallback onAmount;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(t.radiusButton),
          boxShadow: t.depth > 0 ? t.raised(0.7) : null,
          border: t.depth == 0
              ? Border.all(color: t.line, width: t.lineWidth)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: const Key('menuRename'),
                tooltip: context.l10n.rename,
                icon: Icon(Icons.edit_outlined, color: t.text),
                onPressed: onRename,
              ),
              IconButton(
                key: const Key('menuAmount'),
                tooltip: context.l10n.amount,
                icon: Icon(Icons.scale_outlined, color: t.text),
                onPressed: onAmount,
              ),
              IconButton(
                key: const Key('menuDelete'),
                tooltip: context.l10n.delete,
                icon: Icon(Icons.delete_outline, color: t.text),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The six dots at the left of a row whose menu is open: a drag starts from here.
class DragHandle extends StatelessWidget {
  const DragHandle({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.moveProduct,
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Icon(Icons.drag_indicator, color: context.tokens.muted),
    ),
  );
}
