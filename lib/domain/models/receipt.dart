import 'money.dart';

/// What a scanned receipt says about the trip as a whole. The line prices live on the
/// marks; this holds what no line owns: the store, the date, the printed total and a
/// discount of the whole receipt (loyalty bonus). A trip can hold several receipts.
class Receipt {
  const Receipt({this.store, this.date, this.total, this.discount});

  final String? store;
  final DateTime? date;

  /// The total printed on the receipt, kept to check the lines against; null = unread.
  final Money? total;

  /// Saved by the receipt as a whole (>= 0); null = none known.
  final Money? discount;

  @override
  bool operator ==(Object other) =>
      other is Receipt &&
      other.store == store &&
      other.date == date &&
      other.total == total &&
      other.discount == discount;

  @override
  int get hashCode => Object.hash(store, date, total, discount);
}
