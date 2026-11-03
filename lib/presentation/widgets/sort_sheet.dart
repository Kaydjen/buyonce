import 'package:flutter/material.dart';

import '../../domain/models/sort_key.dart';
import '../../l10n/l10n.dart';
import 'card_sheet.dart';

Future<SortKey?> showSortSheet(BuildContext context) {
  // It opens from the menu at the top, so it comes down from there.
  return showCardSheet<SortKey>(
    context,
    fromTop: true,
    builder: (context) {
      final l10n = context.l10n;
      final labels = {
        SortKey.alphabet: l10n.sortAlphabetical,
        SortKey.frequency: l10n.sortFrequent,
        SortKey.recent: l10n.sortRecent,
      };
      return SheetCard(
        children: [
          for (final entry in labels.entries)
            ListTile(
              title: Text(entry.value),
              onTap: () => Navigator.of(context).pop(entry.key),
            ),
        ],
      );
    },
  );
}
