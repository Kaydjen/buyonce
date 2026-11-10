class Product {
  const Product({
    required this.id,
    required this.groupId,
    required this.name,
    required this.position,
    this.planned = false,
    this.plannedBy,
    this.plannedAt,
    this.usage = 0,
    this.deleted = false,
    this.deletedAt,
  });

  final String id;
  final String groupId;
  final String name;

  /// Manual order in the list (ties are broken by [id]). A move takes a value between
  /// its neighbours, so it changes one product only.
  final double position;

  /// "Need" state: planned and pinned to the top.
  final bool planned;

  /// Who made the product needed and when; both are null while it is not planned (and
  /// for seeded data).
  final String? plannedBy;
  final DateTime? plannedAt;

  /// How many sent trips contained this product. The client never writes it: the server
  /// raises it when a trip is sent (backend rules); a new product has 0.
  final int usage;

  /// Taken out of the lists by the user (the "archive"): the product stays, so trips,
  /// plans and the history still know it, but no list, search or ranking shows it. It
  /// comes back through Restore, or when its name is added again.
  final bool deleted;

  /// When it was deleted; null while it is not.
  final DateTime? deletedAt;

  /// Planning sets [plannedBy] and [plannedAt] (when given), un-planning clears them.
  Product copyWith({
    String? name,
    double? position,
    bool? planned,
    String? plannedBy,
    DateTime? plannedAt,
    int? usage,
    bool? deleted,
    DateTime? deletedAt,
  }) {
    final isPlanned = planned ?? this.planned;
    final isDeleted = deleted ?? this.deleted;
    return Product(
      id: id,
      groupId: groupId,
      name: name ?? this.name,
      position: position ?? this.position,
      planned: isPlanned,
      plannedBy: isPlanned ? plannedBy ?? this.plannedBy : null,
      plannedAt: isPlanned ? plannedAt ?? this.plannedAt : null,
      usage: usage ?? this.usage,
      deleted: isDeleted,
      deletedAt: isDeleted ? deletedAt ?? this.deletedAt : null,
    );
  }
}

/// Neighbours closer than this are not split again: the list is numbered anew.
const minGap = 1e-6;

/// Catalog order: by position, equal positions (two phones adding on top at once) by id.
int byPosition(Product a, Product b) {
  final c = a.position.compareTo(b.position);
  return c != 0 ? c : a.id.compareTo(b.id);
}
