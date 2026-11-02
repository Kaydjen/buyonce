import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'groove.dart';
import 'panel.dart';

/// A sheet made of raised cards that float above the page with the same margins as the
/// cards of the lists; the sheet itself has no surface. Put [SheetCard]s in [builder]'s
/// column. It comes up from the bottom, or slides down from the top ([fromTop]), where
/// the thing that opens it (the group name) is.
Future<T?> showCardSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool fromTop = false,
}) {
  final t = context.tokens;
  // The page is veiled in its own colour, so the light glow of the cards blends in.
  final veil = t.background.withValues(alpha: 0.8);

  Widget body(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      // Room for the shadows, which the scroll view would cut.
      padding: EdgeInsets.fromLTRB(
        t.gutter,
        t.depth * 2.5,
        t.gutter,
        t.depth * 2 + 8,
      ),
      child: Builder(builder: builder),
    ),
  );

  if (!fromTop) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0x00000000),
      barrierColor: veil,
      elevation: 0,
      showDragHandle: false,
      builder: body,
    );
  }
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: veil,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, _, _) => Align(
      alignment: Alignment.topCenter,
      // A swipe up closes it, like pulling the shade back.
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) < -300) Navigator.of(context).pop();
        },
        child: Material(type: MaterialType.transparency, child: body(context)),
      ),
    ),
    transitionBuilder: (context, animation, _, child) => SlideTransition(
      position: Tween(begin: const Offset(0, -1), end: Offset.zero).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
      ),
      child: child,
    ),
  );
}

/// One raised card of a card sheet: [children] are rows divided by grooves.
class SheetCard extends StatelessWidget {
  const SheetCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Groove(tight: true),
            ),
          children[i],
        ],
      ],
    ),
  );
}
