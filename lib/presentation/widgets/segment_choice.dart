import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'inset.dart';

/// One option of a [SegmentChoice].
class SegmentOption<T> {
  const SegmentOption(this.value, this.label);

  final T value;
  final Widget label;
}

/// Pick one of a few options: a pressed track with a raised pill under the chosen one,
/// with every corner rounded (the stock segmented button squares the inner ones). In
/// flat styles a tint track with a plain pill.
class SegmentChoice<T> extends StatelessWidget {
  const SegmentChoice({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<SegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final row = Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: _Segment(
                chosen: o.value == selected,
                onTap: () => onChanged(o.value),
                child: o.label,
              ),
            ),
        ],
      ),
    );
    return t.depth > 0
        ? Inset(radius: t.radiusButton, scale: 0.6, child: row)
        : DecoratedBox(
            decoration: BoxDecoration(
              color: t.tint,
              borderRadius: BorderRadius.circular(t.radiusButton),
            ),
            child: row,
          );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.chosen,
    required this.onTap,
    required this.child,
  });

  final bool chosen;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = BorderRadius.circular(t.radiusButton);
    return Semantics(
      button: true,
      selected: chosen,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: chosen ? t.surface : const Color(0x00000000),
          borderRadius: radius,
          boxShadow: chosen && t.depth > 0 ? t.raised(0.4) : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 48,
              child: Center(
                child: DefaultTextStyle.merge(
                  style: t.weighted(
                    Theme.of(context).textTheme.labelLarge!
                        .copyWith(color: chosen ? t.text : t.muted),
                    chosen ? t.titleWeight : t.bodyWeight,
                  ),
                  // A long word (another language, large text) shrinks instead of
                  // touching the ends of its segment.
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: FittedBox(fit: BoxFit.scaleDown, child: child),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
