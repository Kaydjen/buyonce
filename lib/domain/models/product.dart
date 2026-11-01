class Product {
  const Product({
    required this.id,
    required this.groupId,
    required this.name,
    required this.position,
    this.planned = false,
    this.plannedBy,
    this.plannedAt,
  });

  final String id;
  final String groupId;
  final String name;

  /// Manual order in the list; new products get the next free position.
  final int position;

  /// "Need" state: planned and pinned to the top.
  final bool planned;

  /// Who made the product needed and when; both are null while it is not planned (and
  /// for seeded data).
  final String? plannedBy;
  final DateTime? plannedAt;

  /// Planning sets [plannedBy] and [plannedAt] (when given), un-planning clears them.
  Product copyWith({
    String? name,
    int? position,
    bool? planned,
    String? plannedBy,
    DateTime? plannedAt,
  }) {
    final isPlanned = planned ?? this.planned;
    return Product(
      id: id,
      groupId: groupId,
      name: name ?? this.name,
      position: position ?? this.position,
      planned: isPlanned,
      plannedBy: isPlanned ? plannedBy ?? this.plannedBy : null,
      plannedAt: isPlanned ? plannedAt ?? this.plannedAt : null,
    );
  }
}
