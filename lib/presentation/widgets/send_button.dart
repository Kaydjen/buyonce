import 'package:flutter/material.dart';

import 'accent_button.dart';
import 'auto_chip.dart';

/// Floating Send button with the count: the only accent of the screen. It slides in
/// with my first unsent mark; above it the auto-send time. While it slides out it keeps
/// what it showed last ("Sent 3"), so it does not flash back to "Send 0" on the way.
class SendButton extends StatefulWidget {
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
  State<SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<SendButton> {
  /// What the button showed while it was on screen; shown again while it leaves.
  late String _text = '${widget.label} ${widget.count}';
  bool _done = false;
  DateTime? _autoSendAt;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final shown = w.visible || w.confirmed != null;
    if (shown) {
      _text = w.confirmed ?? '${w.label} ${w.count}';
      _done = w.confirmed != null;
      _autoSendAt = w.confirmed == null ? w.autoSendAt : null;
    }
    return IgnorePointer(
      ignoring: !shown || w.confirmed != null,
      child: AnimatedSlide(
        // In and out over the right edge of the screen (the button is anchored there).
        offset: shown ? Offset.zero : const Offset(1.8, 0),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
        // Gone from the screen: forget what it showed (the chip counts down no more).
        onEnd: () {
          if (!shown && mounted) setState(() => _autoSendAt = null);
        },
        // Fades only at the end of the way out, when it is already past the edge; on
        // the way in it is visible from the first moment.
        child: AnimatedOpacity(
          opacity: shown ? 1 : 0,
          duration: Duration(milliseconds: shown ? 100 : 320),
          curve: shown ? Curves.linear : const Interval(0.8, 1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_autoSendAt != null) AutoChip(at: _autoSendAt!),
              const SizedBox(height: 8),
              AccentButton(
                buttonKey: w.buttonKey,
                label: _text,
                done: _done,
                onPressed: w.onSend,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
