import '../../l10n/l10n.dart';

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../view_models/list/list_state.dart';
import 'inset.dart';
import 'panel.dart';

/// Bottom two-tab switcher. Classic styles: a bar with a line on top of the selected
/// tab. Pill styles: a panel with a lighter pill for the selected tab. Floating styles:
/// the panel levitates over a list that fades out toward the bottom edge; compact ones
/// are only as wide and as tall as the two tabs.
class ModeBar extends StatelessWidget {
  const ModeBar({super.key, required this.mode, required this.onSelect});

  static const _slide = Duration(milliseconds: 220);

  final ListMode mode;
  final ValueChanged<ListMode> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final row = Row(
      mainAxisSize: t.compactTabs ? MainAxisSize.min : MainAxisSize.max,
      children: [
        _tab(
          context,
          ListMode.need,
          context.l10n.tabPlan,
          const Key('tabPlan'),
        ),
        _tab(context, ListMode.buy, context.l10n.tabShop, const Key('tabShop')),
      ],
    );
    // Long words at a big text size: the compact switcher shrinks to the screen.
    final tabs = t.compactTabs
        ? FittedBox(fit: BoxFit.scaleDown, child: row)
        : row;
    if (t.floatTabs) return _floating(context, tabs);
    if (!t.pillTabs) {
      return Material(
        color: t.surface,
        child: SafeArea(top: false, child: tabs),
      );
    }
    return Material(
      color: t.background,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(t.gutter, 4, t.gutter, 8),
          child: Panel(
            radius: t.radiusButton,
            child: SizedBox(height: 56, child: tabs),
          ),
        ),
      ),
    );
  }

  Widget _floating(BuildContext context, Widget tabs) {
    final t = context.tokens;
    final dark = t.brightness == Brightness.dark;
    final compact = t.compactTabs;
    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: compact ? 110 : 160,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    t.background.withValues(alpha: 0),
                    t.background.withValues(alpha: 0.9),
                    t.background,
                  ],
                  stops: const [0, 0.6, 1],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: compact ? 10 : 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(t.radiusButton),
                boxShadow: t.depth > 0
                    ? t.raised(0.8)
                    : [
                        BoxShadow(
                          color: const Color(0xFF000000)
                              .withValues(alpha: dark ? 0.6 : 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
              ),
              child: t.depth > 0
                  ? Inset(
                      radius: t.radiusButton,
                      scale: 0.7,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: compact
                            ? tabs
                            : SizedBox(width: 240, height: 48, child: tabs),
                      ),
                    )
                  : Panel(
                      radius: t.radiusButton,
                      shadow: false,
                      padding: compact
                          ? const EdgeInsets.all(4)
                          : EdgeInsets.zero,
                      child: compact
                          ? tabs
                          : SizedBox(width: 248, height: 56, child: tabs),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tab(BuildContext context, ListMode m, String label, Key key) {
    final t = context.tokens;
    final selected = mode == m;
    final base = t.compactTabs && t.tabHeight <= 40
        ? Theme.of(context).textTheme.labelLarge!
        : Theme.of(context).textTheme.titleMedium!;
    final text = AnimatedDefaultTextStyle(
      duration: _slide,
      curve: Curves.easeOutCubic,
      style: t.weighted(
        t.controlStyle(base.copyWith(color: selected ? t.text : t.muted)),
        selected ? t.titleWeight : t.bodyWeight,
      ),
      child: Text(label),
    );
    if (t.pillTabs) {
      final plain = Material(
        color: selected && t.depth == 0 ? t.tint : const Color(0x00000000),
        borderRadius: BorderRadius.circular(t.radiusButton),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: key,
          onTap: () => onSelect(m),
          child: t.compactTabs
              ? SizedBox(
                  height: t.tabHeight,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: t.tabHeight > 40 ? 28 : 22,
                    ),
                    child: Center(child: text),
                  ),
                )
              : Center(child: text),
        ),
      );
      // The raised thumb of a pressed track: it rises under the selected tab and sinks
      // out of the other one.
      final pill = t.depth > 0
          ? AnimatedContainer(
              duration: _slide,
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: selected && t.sheen == null ? t.surface : null,
                gradient: selected && t.sheen != null
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [t.sheen!, t.surface],
                      )
                    : null,
                borderRadius: BorderRadius.circular(t.radiusButton),
                boxShadow: selected ? t.raised(0.45) : const [],
              ),
              child: plain,
            )
          : plain;
      return t.compactTabs
          ? pill
          : Expanded(
              child: Padding(padding: const EdgeInsets.all(4), child: pill),
            );
    }
    return Expanded(
      child: InkWell(
        key: key,
        onTap: () => onSelect(m),
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                width: t.tabBarWidth,
                color: selected ? t.text : const Color(0x00000000),
              ),
            ),
          ),
          child: text,
        ),
      ),
    );
  }
}
