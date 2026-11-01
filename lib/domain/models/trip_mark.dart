/// One "taken" mark inside a trip.
class TripMark {
  const TripMark({
    required this.productId,
    required this.userId,
    required this.markedAt,
  });

  final String productId;
  final String userId;
  final DateTime markedAt;
}
