/// One purchase in the history: a product somebody took, and when.
class Purchase {
  const Purchase({
    required this.productName,
    required this.userId,
    required this.markedAt,
  });

  final String productName;
  final String userId;

  /// When the mark was placed (not when the trip was sent: auto-send is later).
  final DateTime markedAt;
}
