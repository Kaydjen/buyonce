import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../view_models/list/list_state.dart';

class ProductRow extends StatelessWidget {
  const ProductRow({
    super.key,
    required this.name,
    this.mark = RowMark.none,
    this.needed = false,
    this.takenBy = '',
    this.addedBy = '',
    this.minHeight = 56,
    required this.showDivider,
    required this.onTap,
  });

  final String name;

  /// Taken product: muted text and tint; a check if I took it, a muted check and the
  /// member's name (up to 10 characters) if someone else did.
  final RowMark mark;

  /// Needed product in Plan: a bar on the left, the row never moves. A taken row shows
  /// its check instead.
  final bool needed;

  /// Name of the member who took the product; shown next to the check for another
  /// member's mark, never for mine.
  final String takenBy;

  /// Shop: the member who made the product needed since my last visit; shown under
  /// the name (accent while open, muted once taken). Empty: nothing is shown.
  final String addedBy;

  /// Row height: Shop rows are taller, they are tapped while walking.
  final double minHeight;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final taken = mark != RowMark.none;
    final content = Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(top: BorderSide(color: context.tokens.line))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    color: taken ? context.tokens.muted : context.tokens.text,
                  ),
                ),
                if (addedBy.isNotEmpty)
                  Text(
                    addedBy,
                    key: const Key('addedBy'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: taken
                          ? context.tokens.muted
                          : context.tokens.accent,
                    ),
                  ),
              ],
            ),
          ),
          if (mark == RowMark.mine)
            Icon(Icons.check, size: 20, color: context.tokens.text)
          else if (mark == RowMark.partner)
            Row(
              key: const Key('partnerMark'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check,
                  key: const Key('partnerCheck'),
                  size: 20,
                  color: context.tokens.muted,
                ),
                const SizedBox(width: 4),
                Text(
                  takenBy,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium!
                      .copyWith(color: context.tokens.muted),
                ),
              ],
            ),
        ],
      ),
    );
    return Material(
      color: taken ? context.tokens.tint : context.tokens.surface,
      child: InkWell(
        onTap: onTap,
        child: needed && !taken
            ? Stack(
                children: [
                  content,
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      key: const Key('needMark'),
                      width: 4,
                      color: context.tokens.needMark,
                    ),
                  ),
                ],
              )
            : content,
      ),
    );
  }
}
