import '../../domain/models/money.dart';

/// [Money] as plain data `{minor, cur}`. Shared by the local-list snapshot and the
/// Firestore mapping. A missing price is a missing key, never a zero.
Map<String, Object> moneyToData(Money m) => {
  'minor': m.minor,
  'cur': m.currency,
};

/// Reads what [moneyToData] wrote; anything else (absent, damaged, a bad currency)
/// gives null: an unreadable price is "no price", never a made-up value.
Money? moneyFromData(Object? data) {
  if (data is! Map) return null;
  final minor = data['minor'];
  final cur = data['cur'];
  if (minor is! num || minor != minor.toInt()) return null;
  if (cur is! String || !RegExp(r'^[A-Z]{3}$').hasMatch(cur)) return null;
  return Money(minor.toInt(), cur);
}
