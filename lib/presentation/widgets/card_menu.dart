import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'card_sheet.dart';

/// One row of a [showCardMenu].
class CardMenuItem<T> {
  const CardMenuItem(this.value, this.label, {this.trailing});

  final T value;
  final String label;

  /// A mark at the end of the row (the dot of an update).
  final Widget? trailing;
}

/// The menu of the "⋮" button: a small raised card that opens where the button is, in
/// the top right corner, on the same veil as the sheets. Returns the chosen value.
Future<T?> showCardMenu<T>(
  BuildContext context, {
  required List<CardMenuItem<T>> items,
}) {
  final t = context.tokens;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: t.background.withValues(alpha: 0.8),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, _, _) => SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          // Room for the shadows around the card.
          padding: EdgeInsets.fromLTRB(
            t.gutter,
            t.depth + 4,
            t.gutter,
            t.depth * 2,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: IntrinsicWidth(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 180),
                child: SheetCard(
                  children: [
                    for (final item in items)
                      ListTile(
                        title: Text(item.label),
                        trailing: item.trailing,
                        onTap: () => Navigator.of(context).pop(item.value),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          alignment: Alignment.topRight,
          scale: Tween(begin: 0.85, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}
