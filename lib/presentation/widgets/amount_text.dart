import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../domain/models/amount.dart';
import '../../l10n/l10n.dart';

/// A number without trailing zeros in the language's own style: 1.5, 2, 0.25.
String plainNumber(BuildContext context, num value) {
  final format = NumberFormat.decimalPattern(
    Localizations.localeOf(context).toString(),
  )..maximumFractionDigits = 3;
  return format.format(value);
}

/// A size in g or ml as people say it: "150 g", "450 ml", "1.5 kg", "1 l". Whole kilos
/// and litres are written from 1000 up.
String sizeText(BuildContext context, int value, {required bool litres}) {
  final l10n = context.l10n;
  if (value < 1000) {
    return '${plainNumber(context, value)} ${litres ? l10n.unitMl : l10n.unitG}';
  }
  return '${plainNumber(context, value / 1000)} ${litres ? l10n.unitL : l10n.unitKg}';
}

/// The measure of one unit: "500 g", "1.5 kg", "250 ml", "1.5 l"; empty when none is set.
String measureText(BuildContext context, Amount a) => [
  if (a.grams case final g?) sizeText(context, g, litres: false),
  if (a.millilitres case final ml?) sizeText(context, ml, litres: true),
].join(' ');

/// What a row shows: "x2" (count alone), "1.5 kg" (size alone, count 1) or "2 × 1.5 kg";
/// empty for [Amount.none]. A part that is not set leaves no trace, not even its sign.
String amountText(BuildContext context, Amount a) {
  final measure = measureText(context, a);
  if (a.count > 1 && measure.isNotEmpty) return '${a.count} × $measure';
  if (a.count > 1) return context.l10n.amountCount(a.count);
  return measure;
}
