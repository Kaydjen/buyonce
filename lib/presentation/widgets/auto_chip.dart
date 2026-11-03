import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../l10n/l10n.dart';

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

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  String _text(BuildContext context) {
    final left = widget.at.difference(DateTime.now());
    if (left < const Duration(minutes: 1)) {
      return context.l10n.autoInSeconds(left.inSeconds.clamp(1, 59));
    }
    if (left <= const Duration(minutes: 10)) {
      final minutes = (left.inSeconds / 60).ceil().clamp(1, 10);
      return context.l10n.autoInMinutes(minutes);
    }
    final t = widget.at.toLocal();
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return context.l10n.autoAt('$hh:$mm');
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
        _text(context),
        style: Theme.of(context).textTheme.bodySmall!
            .copyWith(color: context.tokens.muted),
      ),
    );
  }
}
