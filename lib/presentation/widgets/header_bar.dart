import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// The shell of the top bar of Plan and Shop: one height, one shape in both modes. In
/// styles with a header tone the Shop bar sits on a tint plate.
class HeaderBar extends StatelessWidget {
  const HeaderBar({super.key, required this.shop, required this.child});

  final bool shop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      margin: t.pillTabs && !t.bigHeader
          ? EdgeInsets.symmetric(horizontal: t.inset, vertical: 4)
          : null,
      decoration: BoxDecoration(
        color: shop && t.headerTone ? t.tint : t.background,
        borderRadius: t.pillTabs ? BorderRadius.circular(t.radiusCard) : null,
      ),
      padding: EdgeInsets.only(left: t.bigHeader ? t.gutter : 8, right: 4),
      height: t.bigHeader ? (t.statusInline ? 60 : 72) : 56,
      child: child,
    );
  }
}

/// Style of a top bar text button: a tint plate in the styles that want buttons to look
/// like buttons, plain muted text otherwise.
ButtonStyle headerButtonStyle(BuildContext context) {
  final t = context.tokens;
  if (!t.plateButtons) return TextButton.styleFrom(foregroundColor: t.muted);
  return TextButton.styleFrom(
    foregroundColor: t.text,
    backgroundColor: t.tint,
    minimumSize: const Size(0, 40),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(t.radiusButton),
    ),
  );
}

/// Style of the round menu button of the top bar; the default one without plates.
ButtonStyle? headerIconStyle(BuildContext context) {
  final t = context.tokens;
  if (!t.plateButtons) return null;
  return IconButton.styleFrom(
    backgroundColor: t.tint,
    foregroundColor: t.text,
    fixedSize: const Size(40, 40),
  );
}

/// "4 to buy" in the top bar of Plan: a status, so never a plate. With plated buttons
/// the number takes the accent.
class HeaderStatus extends StatelessWidget {
  const HeaderStatus(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = Theme.of(context).textTheme.bodyMedium!;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: t.plateButtons ? 12 : 8),
      child: t.plateButtons
          ? Text.rich(
              key: const Key('toBuyCount'),
              TextSpan(
                children: [
                  TextSpan(
                    text: '$count',
                    style: t.weighted(
                      style.copyWith(color: t.ink),
                      t.titleWeight,
                    ),
                  ),
                  TextSpan(text: ' to buy'),
                ],
              ),
              style: style.copyWith(color: t.muted),
            )
          : Text(
              '$count to buy',
              key: const Key('toBuyCount'),
              style: style.copyWith(color: t.muted),
            ),
    );
  }
}
