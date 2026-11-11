import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

/// A small floating card: the count and the size of one unit (weight or volume), each
/// with minus and plus; a tap on a number types it. Hold a button to repeat.
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

/// The next size up or down: steps of 50 below 1000 (a 150 g cheese, a 450 ml yoghurt),
/// 100 up to 5000, then 500. 0 means not set.
int stepSize(int value, {required bool up}) {
  final step = up
      ? (value < 1000 ? 50 : (value < 5000 ? 100 : 500))
      : (value <= 1000 ? 50 : (value <= 5000 ? 100 : 500));
  return (up ? value + step : value - step).clamp(0, Amount.maxGrams);
}

enum _Field { none, count, size }

class _AmountEditorState extends State<AmountEditor> {
  late int _count = widget.initial.count;

  /// The size in g or ml; 0 = not set.
  late int _size = widget.initial.grams ?? widget.initial.millilitres ?? 0;

  /// The size is a volume (ml, l), not a weight (g, kg). A product that has no size
  /// yet starts as a weight.
  late bool _litres =
      widget.initial.millilitres != null && widget.initial.grams == null;

  /// The value that is being typed (a tap on a number), if any.
  _Field _editing = _Field.none;
  final _text = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing != _Field.none) {
        setState(_applyTyped);
      }
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  Amount get _amount => _size == 0
      ? Amount.none.copyWith(count: _count)
      : _litres
      ? Amount.none.copyWith(count: _count, millilitres: _size)
      : Amount.none.copyWith(count: _count, grams: _size);

  /// Takes what was typed: an empty text clears the size and keeps the count.
  void _applyTyped() {
    final value = int.tryParse(_text.text.trim());
    switch (_editing) {
      case _Field.count:
        if (value != null) _count = value.clamp(1, Amount.maxCount);
      case _Field.size:
        _size = (value ?? 0).clamp(0, Amount.maxGrams);
      case _Field.none:
        break;
    }
    _editing = _Field.none;
  }

  void _startTyping(_Field field) {
    setState(() {
      _applyTyped();
      _editing = field;
      final current = field == _Field.count ? _count : _size;
      final empty = current == 0 || (field == _Field.count && current == 1);
      final shown = empty ? '' : '$current';
      _text.value = TextEditingValue(
        text: shown,
        // All selected: the first digit typed replaces the old number.
        selection: TextSelection(baseOffset: 0, extentOffset: shown.length),
      );
    });
    _focus.requestFocus();
  }

  void _changeCount(int delta) => setState(() {
    _applyTyped();
    _count = (_count + delta).clamp(1, Amount.maxCount);
  });

  void _changeSize({required bool up}) => setState(() {
    _applyTyped();
    _size = stepSize(_size, up: up);
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        _applyTyped();
        widget.onDone(_amount);
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
                  fieldKey: const Key('countField'),
                  minusKey: const Key('countLess'),
                  plusKey: const Key('countMore'),
                  value: l10n.amountCount(_count),
                  dim: _count == 1,
                  editing: _editing == _Field.count,
                  controller: _text,
                  focus: _focus,
                  suffix: null,
                  onTapValue: () => _startTyping(_Field.count),
                  onMinus: () => _changeCount(-1),
                  onPlus: () => _changeCount(1),
                ),
                const SizedBox(height: 8),
                _StepRow(
                  valueKey: const Key('amountSize'),
                  fieldKey: const Key('sizeField'),
                  minusKey: const Key('sizeLess'),
                  plusKey: const Key('sizeMore'),
                  value: _size == 0
                      ? '–'
                      : sizeText(context, _size, litres: _litres),
                  dim: _size == 0,
                  editing: _editing == _Field.size,
                  controller: _text,
                  focus: _focus,
                  suffix: _litres ? l10n.unitMl : l10n.unitG,
                  onTapValue: () => _startTyping(_Field.size),
                  onMinus: () => _changeSize(up: false),
                  onPlus: () => _changeSize(up: true),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _UnitChoice(
                      key: const Key('unitKg'),
                      label: l10n.unitWeight,
                      selected: !_litres,
                      onTap: () => setState(() => _litres = false),
                    ),
                    const SizedBox(width: 8),
                    _UnitChoice(
                      key: const Key('unitL'),
                      label: l10n.unitVolume,
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

/// "[-]  value  [+]"; a tap on the value turns it into a number field.
class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.valueKey,
    required this.fieldKey,
    required this.minusKey,
    required this.plusKey,
    required this.value,
    required this.dim,
    required this.editing,
    required this.controller,
    required this.focus,
    required this.suffix,
    required this.onTapValue,
    required this.onMinus,
    required this.onPlus,
  });

  final Key valueKey;
  final Key fieldKey;
  final Key minusKey;
  final Key plusKey;
  final String value;

  /// The default (nothing set): the value is muted.
  final bool dim;
  final bool editing;
  final TextEditingController controller;
  final FocusNode focus;

  /// The unit written after the typed number; null for the count.
  final String? suffix;
  final VoidCallback onTapValue;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = Theme.of(context).textTheme.titleLarge!
        .copyWith(color: dim && !editing ? t.muted : t.text);
    return Row(
      children: [
        _StepButton(
          key: minusKey,
          icon: Icons.remove,
          tooltip: context.l10n.amountLess,
          onStep: onMinus,
        ),
        Expanded(
          child: editing
              ? TextField(
                  key: fieldKey,
                  controller: controller,
                  focusNode: focus,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 5,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => focus.unfocus(),
                  style: style,
                  decoration: InputDecoration(
                    counterText: '',
                    suffixText: suffix,
                    isDense: true,
                  ),
                )
              : InkWell(
                  onTap: onTapValue,
                  borderRadius: BorderRadius.circular(t.radiusButton),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Center(
                      child: Text(
                        value,
                        key: valueKey,
                        textAlign: TextAlign.center,
                        style: style,
                      ),
                    ),
                  ),
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
          constraints: const BoxConstraints(minWidth: 72, minHeight: 44),
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
