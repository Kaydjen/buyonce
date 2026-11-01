/// A saved set of products; a pinned plan acts as a template.
class Plan {
  const Plan({
    required this.id,
    required this.groupId,
    required this.productIds,
    required this.createdAt,
    this.pinned = false,
  });

  final String id;
  final String groupId;
  final List<String> productIds;
  final DateTime createdAt;
  final bool pinned;

  Plan copyWith({DateTime? createdAt, bool? pinned}) => Plan(
    id: id,
    groupId: groupId,
    productIds: productIds,
    createdAt: createdAt ?? this.createdAt,
    pinned: pinned ?? this.pinned,
  );
}
