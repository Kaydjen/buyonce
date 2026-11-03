import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Scrolls its row into view and pulses it once when [flash] is set, at creation or later.
class FlashOnAdd extends StatefulWidget {
  const FlashOnAdd({
    super.key,
    required this.flash,
    required this.child,
    this.onDone,
  });

  final bool flash;

  /// Called when the pulse has ended, so the row is not flashed again if it is rebuilt
  /// later (scrolled out of the list and back).
  final VoidCallback? onDone;
  final Widget child;

  @override
  State<FlashOnAdd> createState() => _FlashOnAddState();
}

class _FlashOnAddState extends State<FlashOnAdd>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _pause + _blink,
    // The system "remove animations" setting would squeeze this to about 0.1 s and the
    // blink would never be seen; it is a soft fade, not motion, so keep its length.
    animationBehavior: AnimationBehavior.preserve,
  );

  /// Short rest after the scroll stops, then one slow pulse.
  static const _pause = Duration(milliseconds: 150);
  static const _blink = Duration(milliseconds: 1800);

  @override
  void initState() {
    super.initState();
    if (widget.flash) _start();
  }

  @override
  void didUpdateWidget(FlashOnAdd old) {
    super.didUpdateWidget(old);
    if (widget.flash && !old.flash) _start();
  }

  void _start() {
    _controller.reset();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Blink only after the scroll has settled, or it is missed mid-motion.
      await Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: _scrollDuration(),
        curve: Curves.easeInOutCubic,
      );
      if (!mounted) return;
      try {
        await _controller.forward().orCancel;
      } on TickerCanceled {
        return;
      }
      if (mounted) widget.onDone?.call();
    });
  }

  /// Longer jumps take longer, so the eye can follow the motion.
  Duration _scrollDuration() {
    final box = context.findRenderObject() as RenderBox;
    final top = box.localToGlobal(Offset.zero).dy;
    final distance = (top - MediaQuery.sizeOf(context).height / 2).abs();
    return Duration(
      milliseconds: (300 + distance * 0.4).clamp(350, 1000).round(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Soft bell: rises and falls slowly, with no sharp edges at either end.
  double get _pulse {
    final elapsed = _controller.value * _controller.duration!.inMilliseconds;
    final t = ((elapsed - _pause.inMilliseconds) / _blink.inMilliseconds).clamp(
      0.0,
      1.0,
    );
    final s = math.sin(math.pi * t);
    return s * s;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => Container(
        foregroundDecoration: BoxDecoration(
          color: context.tokens.text.withValues(alpha: 0.14 * _pulse),
        ),
        child: child,
      ),
    );
  }
}
