import 'package:flutter/material.dart';

import '../../domain/models/sort_key.dart';
import 'card_sheet.dart';

const _labels = {
  SortKey.alphabet: 'Alphabetical',
  SortKey.frequency: 'Most frequent',
  SortKey.recent: 'Recently bought',
};

Future<SortKey?> showSortSheet(BuildContext context) {
  // It opens from the menu at the top, so it comes down from there.
  return showCardSheet<SortKey>(
    context,
    fromTop: true,
    builder: (context) => SheetCard(
      children: [
        for (final entry in _labels.entries)
          ListTile(
            title: Text(entry.value),
            onTap: () => Navigator.of(context).pop(entry.key),
          ),
      ],
    ),
  );
}
