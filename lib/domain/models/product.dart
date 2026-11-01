class Product {
  const Product({
    required this.id,
    required this.groupId,
    required this.name,
    required this.position,
    this.planned = false,
  });

  final String id;
  final String groupId;
  final String name;

  /// Manual order in the list; new products get the next free position.
  final int position;

  /// "Need" state: planned and pinned to the top.
  final bool planned;

  Product copyWith({String? name, int? position, bool? planned}) => Product(
    id: id,
    groupId: groupId,
    name: name ?? this.name,
    position: position ?? this.position,
    planned: planned ?? this.planned,
  );
}
