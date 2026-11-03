import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

/// A screen that could not load, with the one way out.
class LoadFailed extends StatelessWidget {
  const LoadFailed({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.l10n.failedToLoad),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('retryLoad'),
            onPressed: onRetry,
            child: Text(context.l10n.retry),
          ),
        ],
      ),
    );
  }
}
