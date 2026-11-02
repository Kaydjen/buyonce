import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// A divider of the soft styles: a hairline with a light line under it, like between
/// the rows of the lists. Flat styles get the plain hairline. [tight] drops the room
/// above and below, for a line that sits right between two blocks.
class Groove extends StatelessWidget {
  const Groove({super.key, this.tight = false});

  final bool tight;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tight ? 0 : 4),
      child: Column(
        children: [
          Container(height: 1, color: t.line),
          if (t.depth > 0) Container(height: 1, color: t.shadowLight),
        ],
      ),
    );
  }
}
