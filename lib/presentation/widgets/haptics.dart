import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Haptic probe: a short tick on a mark, a firmer one on Send. Off when the system
/// asks for reduced motion. Remove this file and its calls if it does not help.
abstract final class Haptics {
  static void tick(BuildContext context) {
    if (!MediaQuery.disableAnimationsOf(context)) {
      HapticFeedback.selectionClick();
    }
  }

  static void send(BuildContext context) {
    if (!MediaQuery.disableAnimationsOf(context)) {
      HapticFeedback.mediumImpact();
    }
  }
}
