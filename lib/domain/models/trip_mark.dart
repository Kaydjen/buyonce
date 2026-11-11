import 'amount.dart';

/// One "taken" mark inside a trip.
class TripMark {
  const TripMark({
    required this.productId,
    required this.userId,
    required this.markedAt,
    this.amount = Amount.none,
  });

  final String productId;
  final String userId;
  final DateTime markedAt;

  /// How much was taken; copied from the product's need at the moment of marking.
  final Amount amount;

  TripMark copyWith({Amount? amount}) => TripMark(
    productId: productId,
    userId: userId,
    markedAt: markedAt,
    amount: amount ?? this.amount,
  );
}
