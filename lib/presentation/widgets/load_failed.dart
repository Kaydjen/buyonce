import 'package:flutter/material.dart';

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
          const Text('Failed to load'),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('retryLoad'),
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
