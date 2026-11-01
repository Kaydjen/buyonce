import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// A stand-in for the partner's push: who bought what. A tap dismisses it.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({super.key, required this.lines, required this.onDismiss});

  final List<String> lines;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: context.tokens.tint,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onDismiss,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    lines.join('\n'),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.close, size: 18, color: context.tokens.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
