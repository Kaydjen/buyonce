/// What the other user receives when someone presses Notify; a stand-in for a push.
class Notice {
  const Notice({
    required this.id,
    required this.groupId,
    required this.toUserId,
    required this.fromUserId,
    required this.productIds,
    required this.sentAt,
    this.seen = false,
  });

  final String id;
  final String groupId;
  final String toUserId;
  final String fromUserId;
  final List<String> productIds;
  final DateTime sentAt;
  final bool seen;

  Notice copyWith({bool? seen}) => Notice(
    id: id,
    groupId: groupId,
    toUserId: toUserId,
    fromUserId: fromUserId,
    productIds: productIds,
    sentAt: sentAt,
    seen: seen ?? this.seen,
  );
}
