import 'package:flutter/material.dart';

import 'card_title.dart';
import 'groove.dart';
import 'panel.dart';

/// A card with its title inside, centred, like the Shop cards: the title belongs to
/// the card and not to the page above it.
class TitledCard extends StatelessWidget {
  const TitledCard({
    super.key,
    required this.title,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final String title;
  final Widget child;

  /// Around [child], below the title line.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CardTitle(title),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Groove(tight: true),
        ),
        Padding(padding: padding, child: child),
      ],
    ),
  );
}
