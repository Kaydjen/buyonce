import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'haptics.dart';
import 'inset.dart';

/// A row with a title and a switch; the whole row is the tap target. Soft styles: a
/// pressed track with a raised thumb that slides and carries a dot when on. Flat styles:
/// a tint track with a plain thumb. The state reads by the thumb position, not by colour.
class SoftSwitchTile extends StatelessWidget {
  const SoftSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return MergeSemantics(
      child: Semantics(
        toggled: value,
        child: InkWell(
          borderRadius: BorderRadius.circular(t.radiusButton),
          onTap: () {
            Haptics.tick(context);
            onChanged(!value);
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(width: 16),
                _Track(on: value),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Track extends StatelessWidget {
  const _Track({required this.on});

  final bool on;

  static const double _width = 56;
  static const double _height = 32;
  static const double _thumb = 24;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final soft = t.depth > 0;
    final thumb = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: _thumb,
      height: _thumb,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Flat: the thumb darkens when on, since there is no shadow to lift it.
        color: soft ? t.surface : (on ? t.text : t.muted),
        boxShadow: soft ? t.raised(0.4) : null,
      ),
      child: soft
          ? Center(
              child: AnimatedScale(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                scale: on ? 1 : 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.text,
                  ),
                  child: const SizedBox(width: 8, height: 8),
                ),
              ),
            )
          : null,
    );
    final slide = SizedBox(
      width: _width,
      height: _height,
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(padding: const EdgeInsets.all(4), child: thumb),
      ),
    );
    return soft
        ? Inset(radius: _height / 2, scale: 0.5, child: slide)
        : DecoratedBox(
            decoration: BoxDecoration(
              color: t.tint,
              borderRadius: BorderRadius.circular(_height / 2),
            ),
            child: slide,
          );
  }
}
