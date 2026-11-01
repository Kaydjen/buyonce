import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.color});
  final String text;

  /// Muted when null; the accent marks a label the user should notice first.
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium!
          .copyWith(letterSpacing: 0.6, color: color ?? context.tokens.muted),
    ),
  );
}
