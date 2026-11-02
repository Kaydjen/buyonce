import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// The body of a screen with an app bar: what scrolls up under the bar, and down under
/// the phone's buttons, fades into the page colour instead of being cut by a sharp edge.
/// The top fade grows with the scroll offset (none at rest), so the first card is never
/// veiled; the bottom fade can be left out where something else floats there.
class EdgeFade extends StatefulWidget {
  const EdgeFade({super.key, required this.child, this.bottom = true});

  final Widget child;
  final bool bottom;

  /// The scroll distance over which the top fade comes to full strength.
  static const double _topRamp = 24;

  @override
  State<EdgeFade> createState() => _EdgeFadeState();
}

class _EdgeFadeState extends State<EdgeFade> {
  double _top = 0;

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    final top = (n.metrics.pixels / EdgeFade._topRamp).clamp(0.0, 1.0);
    if (top != _top) setState(() => _top = top);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final page = context.tokens.background;
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: widget.child,
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 28,
          child: IgnorePointer(
            child: Opacity(
              opacity: _top,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [page, page.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.bottom)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: MediaQuery.paddingOf(context).bottom + 24,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [page, page.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
