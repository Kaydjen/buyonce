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
    this.onLongPress,
    this.menuLink,
    this.handle,
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

  /// Long press opens the row's menu (rename, delete).
  final VoidCallback? onLongPress;

  /// Set while this row's menu is open: the menu follows the row through it.
  final LayerLink? menuLink;

  /// Set while the menu is open and the row can be reordered: the row slides to the
  /// right and shows it at the left (the drag handle; a drag starts from it only).
  final Widget? handle;

  /// How far the row moves to make room for the handle.
  static const handleSlot = 40.0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final taken = mark != RowMark.none;
    // A row with a rounded tint leaves room for it; its height stays [minHeight].
    final gap = t.inset > 0 ? 2.0 : 0.0;
    final plain = Container(
      constraints: BoxConstraints(minHeight: minHeight - 2 * gap),
      padding: EdgeInsets.only(
        left: t.needDot ? 32 : 16,
        right: 16,
        top: context.tokens.rowPad,
        bottom: context.tokens.rowPad,
      ),
      decoration: BoxDecoration(
        border: showDivider && t.depth == 0
            ? Border(
                top: BorderSide(
                  color: context.tokens.line,
                  width: context.tokens.lineWidth,
                ),
              )
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
                    color: taken
                        ? t.muted
                        // A product to buy in Plan is a little dimmer than the others.
                        : needed
                        ? Color.lerp(t.text, t.muted, 0.4)
                        : t.text,
                  ),
                ),
                if (addedBy.isNotEmpty)
                  Text(
                    addedBy,
                    key: const Key('addedBy'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: taken || !t.accentAsText ? t.muted : t.ink,
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
    // Soft styles: a groove (dark line over a light one) instead of a hairline.
    final content = showDivider && t.depth > 0
        ? Stack(
            children: [
              plain,
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Column(
                    children: [
                      Container(height: 1, color: t.line),
                      Container(height: 1, color: t.shadowLight),
                    ],
                  ),
                ),
              ),
            ],
          )
        : plain;
    final tile = Material(
      // A card that paints its own surface leaves untaken rows clear.
      color: taken && t.depth == 0
          ? t.tint
          : t.depth > 0
          ? const Color(0x00000000)
          : t.surface,
      borderRadius: BorderRadius.circular(t.radiusRow),
      clipBehavior: t.radiusRow > 0 ? Clip.antiAlias : Clip.none,
      child: InkWell(
        borderRadius: BorderRadius.circular(t.radiusRow),
        onTap: onTap,
        onLongPress: onLongPress,
        child: _withHandle(
          needed && !taken
              ? Stack(
                  children: [
                    content,
                    Positioned(
                      left: t.needDot ? 12 : 0,
                      top: 0,
                      bottom: 0,
                      child: t.needDot
                          ? Center(
                              child: Container(
                                key: const Key('needMark'),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  // Grey, not the accent: every needed product has one.
                                  color: t.muted.withValues(alpha: 0.75),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            )
                          : Container(
                              key: const Key('needMark'),
                              width: t.barWidth,
                              color: t.needMark,
                            ),
                    ),
                  ],
                )
              : content,
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: t.inset, vertical: gap),
      child: menuLink == null
          ? tile
          : CompositedTransformTarget(link: menuLink!, child: tile),
    );
  }

  /// The row content slides right when the handle is shown, which appears at the left.
  Widget _withHandle(Widget content) => Stack(
    children: [
      AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(left: handle == null ? 0 : handleSlot),
        child: content,
      ),
      if (handle != null)
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: handleSlot,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 180),
            builder: (context, v, child) => Opacity(opacity: v, child: child),
            child: Center(child: handle),
          ),
        ),
    ],
  );
}
