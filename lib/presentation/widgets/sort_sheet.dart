import 'package:flutter/material.dart';

import '../../domain/models/sort_key.dart';

const _labels = {
  SortKey.alphabet: 'Alphabetical',
  SortKey.frequency: 'Most frequent',
  SortKey.recent: 'Recently bought',
};

Future<SortKey?> showSortSheet(BuildContext context) {
  return showModalBottomSheet<SortKey>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in _labels.entries)
            ListTile(
              title: Text(entry.value),
              onTap: () => Navigator.of(context).pop(entry.key),
            ),
        ],
      ),
    ),
  );
}
