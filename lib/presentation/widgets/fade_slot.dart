import 'package:flutter/material.dart';

/// A bar item that comes and goes with a fade and a small scale instead of popping.
///
/// While it is hidden it is out of the tree (so it cannot be found or tapped). With
/// [space] the room it takes stays as an empty box of that width, so the neighbours
/// never move. The child of the last visible moment is kept while it fades out, so a
/// value that changed on the way out (a count that fell to 0) does not flash.
class FadeSlot extends StatefulWidget {
  const FadeSlot({
    super.key,
    required this.show,
    required this.child,
    this.space,
  });

  final bool show;
  final Widget child;

  /// Width kept while hidden; null gives the room back.
  final double? space;

  @override
  State<FadeSlot> createState() => _FadeSlotState();
}

class _FadeSlotState extends State<FadeSlot> {
  Widget? _shown;

  @override
  Widget build(BuildContext context) {
    if (widget.show || _shown == null) _shown = widget.child;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: widget.show ? 1 : 0),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) {
        if (v == 0) return SizedBox(width: widget.space ?? 0);
        return IgnorePointer(
          ignoring: !widget.show,
          child: Opacity(
            opacity: v,
            child: Transform.scale(scale: 0.85 + 0.15 * v, child: child),
          ),
        );
      },
      child: _shown,
    );
  }
}
