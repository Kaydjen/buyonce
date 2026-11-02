import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// A round raised plate with an icon, for the soft styles. Wrap in the button that
/// handles the tap (PopupMenuButton) or pass [onPressed]. [label] names the button for
/// a screen reader and shows on a long press.
class RaisedIcon extends StatelessWidget {
  const RaisedIcon({
    super.key,
    required this.label,
    required this.child,
    this.onPressed,
    this.size = 44,
  });

  final String label;
  final Widget child;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Tooltip(
      message: label,
      child: Padding(padding: const EdgeInsets.all(4), child: _plate(t)),
    );
  }

  Widget _plate(AppTokens t) => DecoratedBox(
    decoration: BoxDecoration(
      color: t.sheen == null ? t.surface : null,
      gradient: t.sheen == null
          ? null
          : LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [t.sheen!, t.surface],
            ),
      shape: BoxShape.circle,
      boxShadow: t.raised(0.5),
    ),
    child: Material(
      type: MaterialType.transparency,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: IconTheme(
            data: IconThemeData(color: t.text, size: 22),
            child: Center(child: child),
          ),
        ),
      ),
    ),
  );
}
