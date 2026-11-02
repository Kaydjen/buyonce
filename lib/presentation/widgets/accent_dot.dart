import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// The small round mark of the accent: a pending thing (a needed product, a status, the
/// Send button). One shape and one soft colour wherever the accent shows.
class AccentDot extends StatelessWidget {
  const AccentDot({super.key, this.size = 8});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: context.tokens.needMark,
      shape: BoxShape.circle,
    ),
  );
}
