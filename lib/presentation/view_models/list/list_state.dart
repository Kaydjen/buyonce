import '../../../domain/models/amount.dart';
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
    this.frequentIds,
    this.newSince,
    this.askedAt,
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

  /// How many sent trips contained each product; the Shop "Frequent" card ranks by it.
  final Map<String, int> usage;

  /// Product just added by the user; its row scrolls into view and blinks once.
  final String? flashId;

  /// Product activated while searching; it blinks when the search ends and the list regroups.
  final String? pendingFlashId;

  /// Shop: the Frequent card as it was ranked when the user came to the screen. The
  /// order is kept while they stay, so a Send does not reshuffle the card in front of
  /// them; null until the first ranking.
  final List<String>? frequentIds;

  /// When my previous session of this group ended; products another member made needed
  /// after it are "new". Null: no earlier session, nothing is new.
  final DateTime? newSince;

  /// When I last asked the group for products; null if never.
  final DateTime? askedAt;

  /// The "Ask" button: products I made needed after my last ask that nobody has taken
  /// yet (those additions may have been silent), in catalog order.
  List<Product> get askProducts {
    final taken = {...myMarkIds, ...partnerMarkIds};
    return [
      for (final p in products)
        if (p.planned &&
            p.plannedBy == userId &&
            p.plannedAt != null &&
            (askedAt == null || p.plannedAt!.isAfter(askedAt!)) &&
            !taken.contains(p.id))
          p,
    ];
  }

  /// The "New" group: needed products another member planned after [newSince], in
  /// catalog order. A product stays here (marked or not) until it is sent or the next
  /// session starts. Plan's own search dissolves the group into flat results.
  List<Product> get newProducts {
    final since = newSince;
    if (since == null || (mode == ListMode.need && searching)) return const [];
    return [
      for (final p in products)
        if (p.planned &&
            p.plannedBy != null &&
            p.plannedBy != userId &&
            p.plannedAt != null &&
            p.plannedAt!.isAfter(since))
          p,
    ];
  }

  /// [products] without the "New" group: the part of Plan the user can reorder.
  List<Product> get plainProducts {
    final fresh = {for (final p in newProducts) p.id};
    return [
      for (final p in products)
        if (!fresh.contains(p.id)) p,
    ];
  }

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

  /// How much of [p] the row shows: the amount of my mark, else of the partner's mark,
  /// else what is needed.
  Amount amountOf(Product p) {
    for (final mine in [true, false]) {
      for (final t in trips) {
        if ((t.userId == userId) != mine) continue;
        for (final m in t.marks) {
          if (m.productId == p.id) return m.amount;
        }
      }
    }
    return p.need;
  }

  RowMark markOf(String productId) {
    if (myMarkIds.contains(productId)) return RowMark.mine;
    if (partnerMarkIds.contains(productId)) return RowMark.partner;
    return RowMark.none;
  }

  /// Shop "Frequent" card: unplanned products shown before anything is typed.
  static const frequentLimit = 8;

  /// Results are one flat list, so a tap changes a row in place instead of moving it
  /// into another group.
  bool get flatList => searching || (mode == ListMode.buy && finding);

  /// Shop "To buy" card: every needed product, taken ones stay in place until sent.
  List<Product> get toBuy => products.where((p) => p.planned).toList();

  /// Shop "Frequent" card: the ranking of [liveFrequent] as it was when the user came to
  /// the screen ([frequentIds]); products no longer unplanned drop out. A product taken
  /// meanwhile (mine or a partner's) that is not in it is added on top, the newest mark
  /// first; nothing else moves until the next ranking.
  List<Product> get frequent => _frequent(frequentIds);

  /// The ranking now: up to [frequentLimit] unplanned products, the most often sent
  /// first (group-wide, from sent trips), topped up from the catalog in its order, and
  /// above them the unplanned products taken in an open trip.
  List<Product> get liveFrequent => _frequent(null);

  List<Product> _frequent(List<String>? snapshot) {
    final unplanned = [
      for (final p in products)
        if (!p.planned) p,
    ];
    final index = {
      for (var i = 0; i < unplanned.length; i++) unplanned[i].id: i,
    };
    final List<Product> base;
    if (snapshot == null) {
      base =
          ([...unplanned]..sort((a, b) {
                final byUsage = (usage[b.id] ?? 0).compareTo(usage[a.id] ?? 0);
                return byUsage != 0
                    ? byUsage
                    : index[a.id]!.compareTo(index[b.id]!);
              }))
              .take(frequentLimit)
              .toList();
    } else {
      final byId = {for (final p in unplanned) p.id: p};
      base = [
        for (final id in snapshot)
          if (byId[id] != null) byId[id]!,
      ];
    }
    final shown = {for (final p in base) p.id};
    final markedAt = <String, DateTime>{};
    for (final t in trips) {
      for (final m in t.marks) {
        final seen = markedAt[m.productId];
        if (seen == null || m.markedAt.isAfter(seen)) {
          markedAt[m.productId] = m.markedAt;
        }
      }
    }
    final extra =
        unplanned
            .where((p) => !shown.contains(p.id) && markedAt.containsKey(p.id))
            .toList()
          ..sort((a, b) => markedAt[b.id]!.compareTo(markedAt[a.id]!));
    return [...extra, ...base];
  }

  /// What the Frequent card lists: the typed search over the whole catalog, else the
  /// frequent products.
  List<Product> get frequentShown => searching ? visible : frequent;

  /// Plan shows the whole catalog; a typed query narrows either screen to the
  /// matching names. Shop without a query is both cards.
  List<Product> get visible {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return mode == ListMode.buy ? [...toBuy, ...frequent] : products;
    }
    return products.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

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

  /// Products of one Shop card that nobody has taken yet: what its "Mark all" takes.
  List<Product> untakenOf(List<Product> card) {
    final taken = {...myMarkIds, ...partnerMarkIds};
    return [
      for (final p in card)
        if (p.planned && !taken.contains(p.id)) p,
    ];
  }

  /// The Plan counter: needed products nobody has taken yet.
  int get toBuyCount => untaken.length;

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

  /// New live data of the group; [usage] follows the products.
  ListState withData({
    required List<Product> products,
    required List<Trip> trips,
    required List<Plan> plans,
    required List<Notice> notices,
  }) => ListState(
    products: products,
    trips: trips,
    userId: userId,
    notices: notices,
    plans: plans,
    mode: mode,
    query: query,
    finding: finding,
    autoSendAt: autoSendAt,
    usage: {for (final p in products) p.id: p.usage},
    flashId: flashId,
    pendingFlashId: pendingFlashId,
    frequentIds: frequentIds,
    newSince: newSince,
    askedAt: askedAt,
  );

  /// The visit facts counted again (see `ListViewModel.refresh`).
  ListState withSession({DateTime? newSince, DateTime? askedAt}) => ListState(
    products: products,
    trips: trips,
    userId: userId,
    notices: notices,
    plans: plans,
    mode: mode,
    query: query,
    finding: finding,
    autoSendAt: autoSendAt,
    usage: usage,
    flashId: flashId,
    pendingFlashId: pendingFlashId,
    frequentIds: frequentIds,
    newSince: newSince,
    askedAt: askedAt,
  );

  /// [clearFlash] drops the old blink; a given [flashId] then replaces it.
  ListState copyWith({
    ListMode? mode,
    String? query,
    bool? finding,
    DateTime? autoSendAt,
    bool clearAutoSend = false,
    String? flashId,
    bool clearFlash = false,
    String? pendingFlashId,
    bool clearPending = false,
    bool rankFrequent = false,
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
    flashId: flashId ?? (clearFlash ? null : this.flashId),
    pendingFlashId: clearPending ? null : pendingFlashId ?? this.pendingFlashId,
    frequentIds: rankFrequent
        ? [for (final p in liveFrequent) p.id]
        : frequentIds,
    newSince: newSince,
    askedAt: askedAt,
  );
}
