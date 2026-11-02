import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// "Auto · 15:20", and "Auto · in 8 min" for the last ten minutes. It repeats the
/// idle rule, so the user knows the list goes out by itself.
class AutoChip extends StatefulWidget {
  const AutoChip({super.key, required this.at});
  final DateTime at;

  @override
  State<AutoChip> createState() => _AutoChipState();
}

class _AutoChipState extends State<AutoChip> {
  late final Timer _tick;
  String _shown = '';

  @override
  void initState() {
    super.initState();
    _shown = _text;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final text = _text;
      if (text != _shown) setState(() => _shown = text);
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  String get _text {
    final left = widget.at.difference(DateTime.now());
    if (left < const Duration(minutes: 1)) {
      return 'Auto · in ${left.inSeconds.clamp(1, 59)} s';
    }
    if (left <= const Duration(minutes: 10)) {
      final minutes = (left.inSeconds / 60).ceil().clamp(1, 10);
      return 'Auto · in $minutes min';
    }
    final t = widget.at.toLocal();
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return 'Auto · $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('autoChip'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.tokens.depth > 0
            ? context.tokens.surface
            : context.tokens.tint,
        borderRadius: BorderRadius.circular(context.tokens.radiusChip),
        boxShadow: context.tokens.raised(0.4),
      ),
      child: Text(
        _shown,
        style: Theme.of(context).textTheme.bodySmall!
            .copyWith(color: context.tokens.muted),
      ),
    );
  }
}
