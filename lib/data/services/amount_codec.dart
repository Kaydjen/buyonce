import '../../domain/models/amount.dart';

/// An [Amount] as plain data (`count`, `g`, `ml`; defaults are left out). Shared by the
/// local-list snapshot and the Firestore mapping.
Map<String, Object?> amountToData(Amount a) => {
  if (a.count != 1) 'count': a.count,
  if (a.grams != null) 'g': a.grams,
  if (a.millilitres != null) 'ml': a.millilitres,
};

/// Reads what [amountToData] wrote; missing or invalid values give the defaults, so an
/// old or damaged record never breaks a list.
Amount amountFromData(Object? data) {
  if (data is! Map) return Amount.none;
  int? whole(Object? v) => v is num && v == v.toInt() ? v.toInt() : null;
  final count = whole(data['count']);
  final g = whole(data['g']);
  final ml = whole(data['ml']);
  return Amount.none.copyWith(count: count ?? 1, grams: g, millilitres: ml);
}
