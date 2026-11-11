import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../domain/models/amount.dart';
import '../../l10n/l10n.dart';
import 'amount_text.dart';
import 'panel.dart';

/// Opens the amount editor for [name]; the amount that is shown when the card is closed
/// (tap outside, back) goes to [onDone]. Nothing is asked: minus down to the default
/// clears a value.
Future<void> showAmountEditor(
  BuildContext context, {
  required String name,
  required Amount initial,
  required ValueChanged<Amount> onDone,
}) => showDialog<void>(
  context: context,
  barrierColor: context.tokens.background.withValues(alpha: 0.8),
  builder: (_) => AmountEditor(name: name, initial: initial, onDone: onDone),
);

/// A small floating card: the count and the size of one unit (kg or l), each with minus
/// and plus. Hold a button to repeat.
class AmountEditor extends StatefulWidget {
  const AmountEditor({
    super.key,
    required this.name,
    required this.initial,
    required this.onDone,
  });

  final String name;
  final Amount initial;
  final ValueChanged<Amount> onDone;

  @override
  State<AmountEditor> createState() => _AmountEditorState();
}

/// One step of the size: 100 g or 100 ml.
const _step = 100;

class _AmountEditorState extends State<AmountEditor> {
  late int _count = widget.initial.count;

  /// The size in thousandths (g or ml); 0 = not set.
  late int _size = widget.initial.grams ?? widget.initial.millilitres ?? 0;

  /// The size is litres, not kilos. A product that has no size yet starts as kilos.
  late bool _litres =
      widget.initial.millilitres != null && widget.initial.grams == null;

  Amount get _amount => _size == 0
      ? Amount.none.copyWith(count: _count)
      : _litres
      ? Amount.none.copyWith(count: _count, millilitres: _size)
      : Amount.none.copyWith(count: _count, grams: _size);

  void _changeCount(int delta) =>
      setState(() => _count = (_count + delta).clamp(1, Amount.maxCount));

  void _changeSize(int delta) =>
      setState(() => _size = (_size + delta * _step).clamp(0, Amount.maxGrams));

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final sizeText = _size == 0 ? '–' : plainNumber(context, _size / 1000);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) widget.onDone(_amount);
      },
      child: Dialog(
        backgroundColor: const Color(0x00000000),
        elevation: 0,
        insetPadding: EdgeInsets.symmetric(horizontal: t.gutter, vertical: 24),
        child: Panel(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium!.copyWith(color: t.muted),
                ),
                const SizedBox(height: 16),
                _StepRow(
                  valueKey: const Key('amountCount'),
                  minusKey: const Key('countLess'),
                  plusKey: const Key('countMore'),
                  value: l10n.amountCount(_count),
                  dim: _count == 1,
                  onMinus: () => _changeCount(-1),
                  onPlus: () => _changeCount(1),
                ),
                const SizedBox(height: 8),
                _StepRow(
                  valueKey: const Key('amountSize'),
                  minusKey: const Key('sizeLess'),
                  plusKey: const Key('sizeMore'),
                  value: sizeText,
                  dim: _size == 0,
                  onMinus: () => _changeSize(-1),
                  onPlus: () => _changeSize(1),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _UnitChoice(
                      key: const Key('unitKg'),
                      label: l10n.unitKg,
                      selected: !_litres,
                      onTap: () => setState(() => _litres = false),
                    ),
                    const SizedBox(width: 8),
                    _UnitChoice(
                      key: const Key('unitL'),
                      label: l10n.unitL,
                      selected: _litres,
                      onTap: () => setState(() => _litres = true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "[-]  value  [+]".
class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.valueKey,
    required this.minusKey,
    required this.plusKey,
    required this.value,
    required this.dim,
    required this.onMinus,
    required this.onPlus,
  });

  final Key valueKey;
  final Key minusKey;
  final Key plusKey;
  final String value;

  /// The default (nothing set): the value is muted.
  final bool dim;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        _StepButton(
          key: minusKey,
          icon: Icons.remove,
          tooltip: context.l10n.amountLess,
          onStep: onMinus,
        ),
        Expanded(
          child: Text(
            value,
            key: valueKey,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge!
                .copyWith(color: dim ? t.muted : t.text),
          ),
        ),
        _StepButton(
          key: plusKey,
          icon: Icons.add,
          tooltip: context.l10n.amountMore,
          onStep: onPlus,
        ),
      ],
    );
  }
}

/// A round icon button: a tap steps once, holding it repeats.
class _StepButton extends StatefulWidget {
  const _StepButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onStep,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onStep;

  @override
  State<_StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<_StepButton> {
  Timer? _repeat;

  void _start() {
    widget.onStep();
    _repeat?.cancel();
    _repeat = Timer(const Duration(milliseconds: 400), () {
      _repeat = Timer.periodic(
        const Duration(milliseconds: 90),
        (_) => widget.onStep(),
      );
    });
  }

  void _stop() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: widget.tooltip,
      child: Listener(
        onPointerDown: (_) => _start(),
        onPointerUp: (_) => _stop(),
        onPointerCancel: (_) => _stop(),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: t.tint, shape: BoxShape.circle),
          child: Icon(widget.icon, color: t.text),
        ),
      ),
    );
  }
}

class _UnitChoice extends StatelessWidget {
  const _UnitChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: selected ? t.tint : const Color(0x00000000),
      borderRadius: BorderRadius.circular(t.radiusButton),
      child: InkWell(
        borderRadius: BorderRadius.circular(t.radiusButton),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 64, minHeight: 44),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge!
                  .copyWith(color: selected ? t.text : t.muted),
            ),
          ),
        ),
      ),
    );
  }
}
