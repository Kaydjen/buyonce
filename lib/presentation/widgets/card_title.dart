import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// The centred title of a Shop card; [trailing] is a button on the right.
///
/// The title stays in the middle of the card while it fits beside the button; a long
/// title or a wide button (longer words in another language, large text) pushes it to
/// the left instead of putting it under the button.
class CardTitle extends StatelessWidget {
  const CardTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      height: 56,
      child: CustomMultiChildLayout(
        delegate: _TitleLayout(hasTrailing: trailing != null),
        children: [
          LayoutId(
            id: _Slot.title,
            child: Text(
              t.capsTitles ? text.toUpperCase() : text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium!
                  .copyWith(color: t.muted, letterSpacing: t.captionSpacing),
            ),
          ),
          if (trailing != null) LayoutId(id: _Slot.trailing, child: trailing!),
        ],
      ),
    );
  }
}

enum _Slot { title, trailing }

class _TitleLayout extends MultiChildLayoutDelegate {
  _TitleLayout({required this.hasTrailing});

  final bool hasTrailing;

  static const _edge = 16.0;
  static const _gap = 4.0;

  @override
  void performLayout(Size size) {
    var right = size.width - _edge;
    if (hasTrailing) {
      final button = layoutChild(
        _Slot.trailing,
        BoxConstraints.loose(Size(size.width, size.height)),
      );
      positionChild(
        _Slot.trailing,
        Offset(size.width - button.width, (size.height - button.height) / 2),
      );
      right = size.width - button.width - _gap;
    }
    final room = (right - _edge).clamp(0.0, size.width);
    final title = layoutChild(_Slot.title, BoxConstraints(maxWidth: room));
    var x = (size.width - title.width) / 2;
    if (x + title.width > right) x = right - title.width;
    if (x < _edge) x = _edge;
    positionChild(_Slot.title, Offset(x, (size.height - title.height) / 2));
  }

  @override
  bool shouldRelayout(_TitleLayout old) => old.hasTrailing != hasTrailing;
}
