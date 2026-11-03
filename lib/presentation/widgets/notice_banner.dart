import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../domain/models/notice.dart';
import '../../domain/models/product.dart';
import 'accent_dot.dart';
import 'panel.dart';

/// The lines of the banner: one per sender and kind, the products of their notices
/// joined (oldest first, each product once, unknown ones left out). A line shows up to
/// [maxProducts] names, then "+N" for the rest.
List<String> noticeLines(
  List<Notice> notices,
  List<Product> products,
  String Function(String userId) nameOf, {
  int maxProducts = 3,
}) {
  final names = {for (final p in products) p.id: p.name};
  final ordered = [...notices]..sort((a, b) => a.sentAt.compareTo(b.sentAt));
  final groups = <(String, NoticeKind), List<String>>{};
  for (final n in ordered) {
    final list = groups.putIfAbsent((n.fromUserId, n.kind), () => []);
    for (final id in n.productIds) {
      final name = names[id];
      if (name != null && !list.contains(name)) list.add(name);
    }
  }
  return [
    for (final MapEntry(key: (from, kind), value: list) in groups.entries)
      if (list.isNotEmpty)
        '${nameOf(from)} ${kind == NoticeKind.needed ? 'needs' : 'bought'}: '
            '${list.take(maxProducts).join(', ')}'
            '${list.length > maxProducts ? ' +${list.length - maxProducts}' : ''}',
  ];
}

/// A stand-in for the partner's push: who bought or needs what. A tap dismisses it. A
/// raised card like the lists, so it reads as a message, with the small accent dot of
/// something new next to the first line.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({super.key, required this.lines, required this.onDismiss});

  final List<String> lines;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: EdgeInsets.fromLTRB(t.gutter, 4, t.gutter, 12),
      child: Panel(
        child: InkWell(
          onTap: onDismiss,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Level with the middle of the first line.
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: AccentDot(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final line in lines)
                        Text(
                          line,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: style,
                        ),
                    ],
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
