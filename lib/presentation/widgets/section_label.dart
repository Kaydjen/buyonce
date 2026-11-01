import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium!
          .copyWith(letterSpacing: 0.6, color: context.tokens.muted),
    ),
  );
}
