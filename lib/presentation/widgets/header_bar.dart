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

/// Style of a top bar text button: plain muted text.
ButtonStyle headerButtonStyle(BuildContext context) =>
    TextButton.styleFrom(foregroundColor: context.tokens.muted);

/// "4 to buy" in the top bar of Plan: a status, so never a plate.
class HeaderStatus extends StatelessWidget {
  const HeaderStatus(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        '$count to buy',
        key: const Key('toBuyCount'),
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.muted),
      ),
    );
  }
}
