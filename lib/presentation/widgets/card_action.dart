import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// A text button in a card title ("Mark all"). A low raised pill in the styles with card
/// buttons, a plain text button otherwise.
class CardTextAction extends StatelessWidget {
  const CardTextAction({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (!t.cardButtons) {
      return TextButton(onPressed: onPressed, child: Text(label));
    }
    return _Reach(
      onTap: onPressed,
      rightGap: 9,
      child: Ink(
        decoration: cardPlateLook(t, BoxShape.rectangle),
        child: InkWell(
          borderRadius: BorderRadius.circular(t.radiusButton),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _plate),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Text(
                label,
                style: t.weighted(
                  Theme.of(context).textTheme.labelLarge!
                      .copyWith(color: t.muted),
                  t.titleWeight,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const double _plate = 38;

/// The shadow scale of a plate that sits in its card.
const double cardPlateLift = 0.18;

/// The plate of a card button: the gradient and the shadow of the header plates, but a
/// much lower lift, so it sits in the card instead of standing out of it.
BoxDecoration cardPlateLook(
  AppTokens t,
  BoxShape shape, {
  double lift = cardPlateLift,
}) => BoxDecoration(
  shape: shape,
  borderRadius: shape == BoxShape.circle
      ? null
      : BorderRadius.circular(t.radiusButton),
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [t.sheen ?? t.surface, t.surface],
  ),
  boxShadow: t.raised(lift),
);

/// Makes a 38 dp plate react in a 48 dp area: [_slack] more on each side, which still
/// fits the 56 dp card title. The plate keeps its look and its ripple.
class _Reach extends StatelessWidget {
  const _Reach({
    required this.onTap,
    required this.rightGap,
    required this.child,
  });

  static const double _slack = 5;

  final VoidCallback onTap;

  /// Space to the card edge after the touch area.
  final double rightGap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: rightGap),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(_slack), child: child),
      ),
    );
  }
}

/// An icon button in a card title (search). A flat tint round plate in the styles with
/// card buttons, a plain icon button otherwise.
class CardIconAction extends StatelessWidget {
  const CardIconAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;

  /// Names the button for a screen reader and shows on a long press.
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (!t.cardButtons) {
      return IconButton(onPressed: onPressed, tooltip: label, icon: Icon(icon));
    }
    return _Reach(
      onTap: onPressed,
      rightGap: 5,
      child: Tooltip(
        message: label,
        child: Ink(
          decoration: cardPlateLook(t, BoxShape.circle),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: _plate,
              height: _plate,
              child: Icon(icon, size: 20, color: t.muted),
            ),
          ),
        ),
      ),
    );
  }
}
