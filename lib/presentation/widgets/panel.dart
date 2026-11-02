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
    final radius = this.radius ?? t.radiusCard;
    final rim = t.rim;
    return CustomPaint(
      foregroundPainter: rim == null || tinted
          ? null
          : _RimPainter(rim, radius),
      child: Container(
        clipBehavior: Clip.antiAlias,
        padding: padding,
        decoration: BoxDecoration(
          color: tinted || t.sheen == null
              ? (tinted ? t.tint : t.surface)
              : null,
          gradient: tinted || t.sheen == null
              ? null
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [t.sheen!, t.surface],
                ),
          borderRadius: BorderRadius.circular(radius),
          boxShadow: tinted || !shadow ? null : t.raised(),
        ),
        // Ink of the tiles inside paints above the surface, not under it.
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}

/// The light on the top edge of a card: a hairline inside the corner radius, brightest at
/// the top and gone before the middle of the sides.
class _RimPainter extends CustomPainter {
  const _RimPainter(this.color, this.radius);

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    // Only large cards catch the light; on a low panel (the switcher, segments) the
    // line would wrap the whole pill.
    if (size.height < 80) return;
    final shape = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(0.5),
      Radius.circular(radius),
    );
    canvas.drawRRect(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color, color.withValues(alpha: 0)],
          stops: [0, (radius * 1.4 / size.height).clamp(0.01, 1.0)],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_RimPainter old) =>
      color != old.color || radius != old.radius;
}
