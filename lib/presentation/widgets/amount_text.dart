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

/// The measure of one unit: "500 g", "1.5 kg", "250 ml", "1.5 l"; empty when none is set.
/// Whole kilos and litres are written from 1000 up.
String measureText(BuildContext context, Amount a) {
  final l10n = context.l10n;
  final parts = <String>[];
  final g = a.grams;
  if (g != null) {
    parts.add(
      g < 1000
          ? '${plainNumber(context, g)} ${l10n.unitG}'
          : '${plainNumber(context, g / 1000)} ${l10n.unitKg}',
    );
  }
  final ml = a.millilitres;
  if (ml != null) {
    parts.add(
      ml < 1000
          ? '${plainNumber(context, ml)} ${l10n.unitMl}'
          : '${plainNumber(context, ml / 1000)} ${l10n.unitL}',
    );
  }
  return parts.join(' ');
}

/// What a row shows: "x2", "1.5 kg" or "x2 1.5 l"; empty for [Amount.none].
String amountText(BuildContext context, Amount a) => [
  if (a.count > 1) context.l10n.amountCount(a.count),
  measureText(context, a),
].where((s) => s.isNotEmpty).join(' ');
