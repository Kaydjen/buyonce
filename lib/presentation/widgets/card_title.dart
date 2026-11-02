import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// The centred title of a Shop card; [trailing] is a button on the right.
class CardTitle extends StatelessWidget {
  const CardTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            // Room for a button on the right; the title stays centred.
            padding: EdgeInsets.symmetric(
              horizontal: trailing == null ? 16 : 112,
            ),
            child: Text(
              t.capsTitles ? text.toUpperCase() : text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium!
                  .copyWith(color: t.muted, letterSpacing: t.captionSpacing),
            ),
          ),
          if (trailing != null)
            Align(alignment: Alignment.centerRight, child: trailing),
        ],
      ),
    );
  }
}
