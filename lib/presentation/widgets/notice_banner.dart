import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'accent_dot.dart';
import 'panel.dart';

/// A stand-in for the partner's push: who bought what. A tap dismisses it. A raised
/// card like the lists, so it reads as a message, with the small accent dot of
/// something new.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({super.key, required this.lines, required this.onDismiss});

  final List<String> lines;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(t.gutter, 4, t.gutter, 12),
      child: Panel(
        child: InkWell(
          onTap: onDismiss,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                const AccentDot(),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lines.join('\n'),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.close, size: 18, color: t.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
