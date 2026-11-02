import 'package:flutter/material.dart';

import 'accent_button.dart';
import 'auto_chip.dart';

/// Floating Send button with the count: the only accent of the screen. It slides in
/// with my first unsent mark; above it the auto-send time.
class SendButton extends StatelessWidget {
  const SendButton({
    super.key,
    this.buttonKey = const Key('sendButton'),
    required this.visible,
    required this.count,
    required this.autoSendAt,
    required this.onSend,
    required this.label,
    this.confirmed,
  });
  final Key buttonKey;
  final bool visible;
  final int count;
  final DateTime? autoSendAt;
  final VoidCallback onSend;

  /// "Send" in a group; "Done" in the personal list, where nobody is notified.
  final String label;

  /// Text of the confirmation ("Sent 4"): the button stays a moment and shows it, so
  /// the user sees the send happened where they pressed.
  final String? confirmed;

  @override
  Widget build(BuildContext context) {
    final shown = visible || confirmed != null;
    return IgnorePointer(
      ignoring: !shown || confirmed != null,
      child: AnimatedSlide(
        offset: shown ? Offset.zero : const Offset(0, 2),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: shown ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (autoSendAt != null && confirmed == null)
                AutoChip(at: autoSendAt!),
              const SizedBox(height: 8),
              AccentButton(
                buttonKey: buttonKey,
                label: confirmed ?? '$label $count',
                done: confirmed != null,
                onPressed: onSend,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
