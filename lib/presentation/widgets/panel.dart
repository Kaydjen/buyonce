import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// The one block every screen is built from: lists, settings sections, history days,
/// the notice. A soft gradient surface with a hairline edge; [tinted] is the flat
/// plate used for the active or transient thing (the notice).
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.tinted = false,
    this.radius,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool tinted;

  /// Corner radius; the card radius when null.
  final double? radius;

  /// A raised look in the soft styles; off when a parent already draws the shadow.
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final lift = t.lift;
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: padding,
      decoration: BoxDecoration(
        color: tinted ? t.tint : (lift == null ? t.surface : null),
        gradient: tinted || lift == null
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [lift, t.surface],
              ),
        borderRadius: BorderRadius.circular(radius ?? t.radiusCard),
        boxShadow: tinted || !shadow ? null : t.raised(),
        border: t.cardOutline
            ? Border.all(color: t.line, width: t.lineWidth)
            : null,
      ),
      // Ink of the tiles inside paints above the surface, not under it.
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}
