import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// A pressed (concave) shape of the soft styles: the fill with a dark inner shadow on the
/// top left and a light one on the bottom right. In flat styles a plain tint plate.
class Inset extends StatelessWidget {
  const Inset({
    super.key,
    required this.radius,
    required this.child,
    this.scale = 1,
    this.amount = 1,
  });

  final double radius;
  final Widget child;

  /// Multiplies the depth; smaller for small shapes.
  final double scale;

  /// 0 (level with the surface) to 1 (fully pressed); lets a shape sink and rise.
  final double amount;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = t.shadowDark;
    final light = t.shadowLight;
    if (t.depth == 0 || dark == null || light == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: t.tint,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child,
      );
    }
    return CustomPaint(
      painter: _InsetPainter(
        fill: t.surface,
        dark: dark,
        light: light,
        radius: radius,
        depth: t.depth * scale * amount,
      ),
      child: child,
    );
  }
}

class _InsetPainter extends CustomPainter {
  const _InsetPainter({
    required this.fill,
    required this.dark,
    required this.light,
    required this.radius,
    required this.depth,
  });

  final Color fill;
  final Color dark;
  final Color light;
  final double radius;
  final double depth;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas.save();
    canvas.clipRRect(shape);
    canvas.drawRRect(shape, Paint()..color = fill);
    // Everything outside the shape, blurred and shifted in: it shades the inner edge.
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(shape.outerRect.inflate(depth * 6))
      ..addRRect(shape);
    final blur = MaskFilter.blur(BlurStyle.normal, depth * 0.55);
    canvas.save();
    canvas.translate(depth * 0.7, depth * 0.7);
    canvas.drawPath(
      outside,
      Paint()
        ..color = dark
        ..maskFilter = blur,
    );
    canvas.restore();
    canvas.save();
    canvas.translate(-depth * 0.7, -depth * 0.7);
    canvas.drawPath(
      outside,
      Paint()
        ..color = light
        ..maskFilter = blur,
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InsetPainter old) =>
      fill != old.fill ||
      dark != old.dark ||
      light != old.light ||
      radius != old.radius ||
      depth != old.depth;
}

/// A text field of the soft styles sits in a pressed shape instead of a filled plate.
/// Other styles keep the field as it is.
class SoftField extends StatelessWidget {
  const SoftField({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (t.depth == 0) return child;
    final theme = Theme.of(context);
    return Inset(
      radius: t.radiusField,
      scale: 0.7,
      child: Theme(
        data: theme.copyWith(
          inputDecorationTheme: theme.inputDecorationTheme.copyWith(
            filled: false,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// A segmented control of the soft styles sits in a pressed track.
class SoftSegments extends StatelessWidget {
  const SoftSegments({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (t.depth == 0) return child;
    return Inset(
      radius: t.radiusButton,
      scale: 0.6,
      child: Padding(padding: const EdgeInsets.all(4), child: child),
    );
  }
}
