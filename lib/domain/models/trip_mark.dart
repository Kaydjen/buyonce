import 'amount.dart';
import 'money.dart';

/// One "taken" mark inside a trip.
class TripMark {
  const TripMark({
    required this.productId,
    required this.userId,
    required this.markedAt,
    this.amount = Amount.none,
    this.price,
    this.discount,
    this.receiptText,
  });

  final String productId;
  final String userId;
  final DateTime markedAt;

  /// How much was taken; copied from the product's need at the moment of marking.
  final Amount amount;

  /// What was paid for the whole line (after a line discount); null = unknown. Only a
  /// scanned receipt sets it, no screen asks for it.
  final Money? price;

  /// What the line saved (>= 0); null = no discount known. The price before the
  /// discount is `price + discount`.
  final Money? discount;

  /// The printed receipt line(s) this mark came from, when a scanned receipt made it:
  /// the trace that lets a wrong tick be found later ("Картошка <- Podu ku Mega"). Null
  /// for a mark made by a tap.
  final String? receiptText;

  TripMark copyWith({
    Amount? amount,
    Money? price,
    Money? discount,
    String? receiptText,
    bool clearPrice = false,
    bool clearDiscount = false,
  }) => TripMark(
    productId: productId,
    userId: userId,
    markedAt: markedAt,
    amount: amount ?? this.amount,
    price: clearPrice ? null : price ?? this.price,
    discount: clearDiscount ? null : discount ?? this.discount,
    receiptText: receiptText ?? this.receiptText,
  );
}
