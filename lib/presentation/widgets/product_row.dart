import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../view_models/list/list_state.dart';

class ProductRow extends StatelessWidget {
  const ProductRow({
    super.key,
    required this.name,
    this.mark = RowMark.none,
    this.planned = false,
    this.takenBy = '',
    this.minHeight = 56,
    required this.showDivider,
    required this.onTap,
  });

  final String name;

  /// Taken product: muted text and tint; a check if I took it, a muted check and the
  /// member's name (up to 10 characters) if someone else did.
  final RowMark mark;

  /// Planned product shown inside a flat search result: a plain check, no dimming.
  final bool planned;

  /// Name of the member who took the product; shown next to the check for another
  /// member's mark, never for mine.
  final String takenBy;

  /// Row height: Shop rows are taller, they are tapped while walking.
  final double minHeight;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final taken = mark != RowMark.none;
    return Material(
      color: taken ? context.tokens.tint : context.tokens.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
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
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    color: taken ? context.tokens.muted : context.tokens.text,
                  ),
                ),
              ),
              if (mark == RowMark.mine)
                Icon(Icons.check, size: 20, color: context.tokens.accent)
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
                )
              else if (planned)
                Icon(Icons.check, size: 20, color: context.tokens.text),
            ],
          ),
        ),
      ),
    );
  }
}
