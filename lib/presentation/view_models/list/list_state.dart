import '../../../domain/models/notice.dart';
import '../../../domain/models/plan.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/trip.dart';

enum ListMode { need, buy }

/// Who marked a product as taken in the open trips.
enum RowMark { none, mine, partner }

class ListState {
  const ListState({
    this.products = const [],
    this.trips = const [],
    this.userId = 'me',
    this.notices = const [],
    this.plans = const [],
    this.mode = ListMode.need,
    this.query = '',
    this.finding = false,
    this.autoSendAt,
    this.usage = const {},
    this.flashId,
    this.pendingFlashId,
  });

  final List<Product> products;

  /// Open trips of the group: mine and the partner's.
  final List<Trip> trips;
  final String userId;

  /// Notifications from the partner that this user has not dismissed.
  final List<Notice> notices;
  final List<Plan> plans;
  final ListMode mode;
  final String query;

  /// Shop only: the search field is open to mark a product that is not in the plan.
  final bool finding;

  /// When my idle trip is sent by itself; null without unsent marks.
  final DateTime? autoSendAt;

  /// How many sent trips contained each product; the Shop search offers the most
  /// frequent products before anything is typed.
  final Map<String, int> usage;

  /// Product just added by the user; its row scrolls into view and blinks once.
  final String? flashId;

  /// Product activated while searching; it blinks when the search ends and the list regroups.
  final String? pendingFlashId;

  bool get searching => query.trim().isNotEmpty;

  Set<String> get myMarkIds => {
    for (final t in trips)
      if (t.userId == userId)
        for (final m in t.marks) m.productId,
  };

  Set<String> get partnerMarkIds => {
    for (final t in trips)
      if (t.userId != userId)
        for (final m in t.marks) m.productId,
  };

  RowMark markOf(String productId) {
    if (myMarkIds.contains(productId)) return RowMark.mine;
    if (partnerMarkIds.contains(productId)) return RowMark.partner;
    return RowMark.none;
  }

  /// Shop search before typing: a few frequent products outside the plan.
  static const suggestionCount = 5;

  /// Results are one flat list, so a tap changes a row in place instead of moving it
  /// into another group.
  bool get flatList => searching || (mode == ListMode.buy && finding);

  /// Plan shows the whole catalog. Shop shows the needed products and whatever has
  /// been taken in an open trip; its search reaches the whole catalog.
  List<Product> get visible {
    final q = query.trim().toLowerCase();
    if (mode == ListMode.buy && finding && q.isEmpty) {
      final taken = {...myMarkIds, ...partnerMarkIds};
      return (products
              .where(
                (p) =>
                    !p.planned &&
                    !taken.contains(p.id) &&
                    (usage[p.id] ?? 0) > 0,
              )
              .toList()
            ..sort((a, b) => (usage[b.id] ?? 0).compareTo(usage[a.id] ?? 0)))
          .take(suggestionCount)
          .toList();
    }
    final taken = {...myMarkIds, ...partnerMarkIds};
    return products
        .where(
          (p) =>
              (mode == ListMode.need ||
                  finding ||
                  p.planned ||
                  taken.contains(p.id)) &&
              (q.isEmpty || p.name.toLowerCase().contains(q)),
        )
        .toList();
  }

  List<Product> get plannedVisible => visible.where((p) => p.planned).toList();
  List<Product> get restVisible => visible.where((p) => !p.planned).toList();

  Product? get exactMatch {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;
    return visible.where((p) => p.name.toLowerCase() == q).firstOrNull;
  }

  bool get canReorder => !flatList;

  /// Nothing in the catalog matches the typed name: offer to add it (planned in Plan,
  /// taken in Shop).
  bool get canAdd =>
      (mode == ListMode.need || finding) &&
      query.trim().isNotEmpty &&
      visible.isEmpty;

  /// Needed products nobody has taken yet: what "mark all" takes.
  List<Product> get untaken {
    final taken = {...myMarkIds, ...partnerMarkIds};
    return products.where((p) => p.planned && !taken.contains(p.id)).toList();
  }

  /// Other members with open marks and how many products each has taken.
  Map<String, int> get othersTaken => {
    for (final t in trips)
      if (t.userId != userId && t.marks.isNotEmpty) t.userId: t.marks.length,
  };

  /// Who took the product, when it is not me.
  String? partnerOf(String productId) => trips
      .where(
        (t) =>
            t.userId != userId && t.marks.any((m) => m.productId == productId),
      )
      .map((t) => t.userId)
      .firstOrNull;

  /// Unsent marks of mine: the Notify button shows while there are any.
  bool get hasUnsent => myMarkIds.isNotEmpty;
  int get plannedCount => products.where((p) => p.planned).length;

  ListState copyWith({
    ListMode? mode,
    String? query,
    bool? finding,
    DateTime? autoSendAt,
    bool clearAutoSend = false,
    String? flashId,
    String? pendingFlashId,
    bool clearPending = false,
  }) => ListState(
    products: products,
    trips: trips,
    userId: userId,
    notices: notices,
    plans: plans,
    mode: mode ?? this.mode,
    query: query ?? this.query,
    finding: finding ?? this.finding,
    autoSendAt: clearAutoSend ? null : autoSendAt ?? this.autoSendAt,
    usage: usage,
    flashId: flashId ?? this.flashId,
    pendingFlashId: clearPending ? null : pendingFlashId ?? this.pendingFlashId,
  );
}
