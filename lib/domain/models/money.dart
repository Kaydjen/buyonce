import 'package:intl/intl.dart';

/// An amount of money in minor units (cents, kopiykas) and its ISO 4217 currency.
///
/// "No price" is never a `Money`: a missing price is `null` everywhere (a Firestore field
/// that is absent), because 0 is a real price (a free item) and a sentinel would be added
/// into sums by mistake. Integers only, no floats.
class Money {
  const Money(this.minor, this.currency);

  final int minor;

  /// Upper case ISO code, e.g. `UAH`, `PLN`.
  final String currency;

  Money copyWith({int? minor}) => Money(minor ?? this.minor, currency);

  @override
  bool operator ==(Object other) =>
      other is Money && other.minor == minor && other.currency == currency;

  @override
  int get hashCode => Object.hash(minor, currency);

  @override
  String toString() => 'Money($minor $currency)';
}

/// How many digits a currency has after the decimal separator (UAH 2, JPY 0, KWD 3).
int currencyDigits(String currency) =>
    NumberFormat.currency(name: currency).decimalDigits ?? 2;

/// The result of [sumMoney]: one total per currency (currencies never mix) and how many
/// lines had no price. A caller that needs a complete sum checks `missing == 0`.
class MoneySum {
  const MoneySum(this.totals, this.missing);

  /// Minor units per currency; a currency appears only when a line has a price in it.
  final Map<String, int> totals;

  /// Lines without a price (null): never counted as 0.
  final int missing;

  /// True when every line had a price.
  bool get complete => missing == 0;

  /// The single total when there is exactly one currency, else null.
  Money? get single {
    if (totals.length != 1) return null;
    final e = totals.entries.first;
    return Money(e.value, e.key);
  }
}

/// Adds prices; a null price is counted in [MoneySum.missing], not as 0.
MoneySum sumMoney(Iterable<Money?> prices) {
  final totals = <String, int>{};
  var missing = 0;
  for (final p in prices) {
    if (p == null) {
      missing++;
    } else {
      totals[p.currency] = (totals[p.currency] ?? 0) + p.minor;
    }
  }
  return MoneySum(totals, missing);
}

/// Turns the text of a receipt ("32,90", "1 234.50", "1.234,50", "-5,00") into minor
/// units of [currency], or null when it is not a number or has more decimals than the
/// currency has.
///
/// The decimal separator is the last "." or "," when both appear; a single separator
/// that occurs once is decimal, except when exactly three digits follow it and the
/// currency does not have three ("1,234" is 1234); a repeated separator is a grouping.
Money? parseMoney(String text, String currency) {
  var s = text.trim().replaceAll(RegExp('[\\s   \']'), '');
  if (s.isEmpty) return null;
  var negative = false;
  if (s.startsWith('-') || s.startsWith('−')) {
    negative = true;
    s = s.substring(1);
  } else if (s.startsWith('+')) {
    s = s.substring(1);
  }
  if (!RegExp(r'^[0-9.,]+$').hasMatch(s) || !RegExp('[0-9]').hasMatch(s)) {
    return null;
  }
  final code = currency.toUpperCase();
  final digits = currencyDigits(code);
  final lastDot = s.lastIndexOf('.');
  final lastComma = s.lastIndexOf(',');
  final lastSep = lastDot > lastComma ? lastDot : lastComma;

  String whole = s;
  String frac = '';
  if (lastSep >= 0) {
    final sep = s[lastSep];
    final after = s.length - lastSep - 1;
    final before = s.substring(0, lastSep);
    final other = sep == '.' ? ',' : '.';
    final repeated = s.indexOf(sep) != lastSep;
    final decimal = !repeated &&
        (before.contains(other) || !(after == 3 && digits != 3));
    if (decimal) {
      whole = before.replaceAll(RegExp('[.,]'), '');
      frac = s.substring(lastSep + 1);
    } else {
      // A grouping separator: every separator must sit between groups of three.
      final groups = s.split(RegExp('[.,]'));
      if (groups.skip(1).any((g) => g.length != 3)) return null;
      whole = groups.join();
    }
  }
  if (whole.isEmpty && frac.isEmpty) return null;
  if (frac.length > digits) return null;
  final padded = frac.padRight(digits, '0');
  final major = whole.isEmpty ? 0 : int.tryParse(whole);
  final minor = padded.isEmpty ? 0 : int.tryParse(padded);
  if (major == null || minor == null) return null;
  var scale = 1;
  for (var i = 0; i < digits; i++) {
    scale *= 10;
  }
  final value = major * scale + minor;
  return Money(negative ? -value : value, code);
}
