import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/result.dart';
import '../../../data/repositories/list_repository.dart';
import '../../../domain/models/notice.dart';
import '../../../domain/models/plan.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/product_names.dart';
import '../../../domain/models/sort_key.dart';
import '../../../domain/models/trip.dart';
import '../groups/groups_view_model.dart';
import '../session/session.dart';
import '../settings/settings_view_model.dart';
import 'list_state.dart';
import 'sync_state.dart';

/// The screen the user was on last; kept across group switches (the view model is
/// rebuilt then). Null until the user switches once.
class LastMode extends Notifier<ListMode?> {
  @override
  ListMode? build() => null;

  void select(ListMode mode) => state = mode;
}

final lastModeProvider = NotifierProvider<LastMode, ListMode?>(LastMode.new);

/// How long a user can stay idle in a trip before it is sent automatically; null
/// when auto-send is switched off in Settings.
final autoNotifyDelayProvider = Provider<Duration?>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.autoSendEnabled
      ? Duration(seconds: settings.autoSendSeconds)
      : null;
});

/// Idle timers, one per group and user with an open trip. They live outside the view
/// model, which is rebuilt when the group changes, and only as long as the process.
final idleTimersProvider = Provider<Map<String, Timer>>((ref) {
  final timers = <String, Timer>{};
  ref.onDispose(() {
    for (final timer in timers.values) {
      timer.cancel();
    }
  });
  return timers;
});

/// When each idle timer fires, by the same key; the Shop shows it as "Auto · 15:20".
/// How much later than the phone's own timer the server sends an idle trip.
const serverSendGrace = Duration(seconds: 30);

final idleDeadlinesProvider = Provider<Map<String, DateTime>>((_) => {});

class ListViewModel extends AsyncNotifier<ListState> {
  /// Counts the builds (see the stale check in [build]).
  int _generation = 0;

  @override
  Future<ListState> build() async {
    // Switching auto-send off stops the running countdowns; a new period only
    // applies from the next mark.
    ref.listen(autoNotifyDelayProvider, (_, delay) {
      if (delay != null) return;
      final timers = ref.read(idleTimersProvider);
      // The server holds a lease for each running countdown: drop it too, or the
      // cron would still send the trip.
      for (final key in timers.keys) {
        final at = key.indexOf('/');
        if (at < 0) continue;
        unawaited(
          ref
              .read(listRepositoryForProvider(key.substring(0, at)))
              .setAutoSendAt(key.substring(at + 1), null),
        );
      }
      for (final timer in timers.values) {
        timer.cancel();
      }
      timers.clear();
      ref.read(idleDeadlinesProvider).clear();
      // Not during a build: the change can arrive while Settings rebuilds.
      scheduleMicrotask(() {
        if (ref.mounted && state.hasValue) {
          state = AsyncData(state.requireValue.copyWith(clearAutoSend: true));
        }
      });
    });
    final repo = ref.watch(listRepositoryProvider);
    // A user switch (debug) starts the list over for that user.
    final userId = ref.watch(currentUserIdProvider);
    final subscriptions = <StreamSubscription<Object?>>[];
    ref.onDispose(() {
      for (final subscription in subscriptions) {
        subscription.cancel();
      }
    });
    final generation = ++_generation;
    // A build that was replaced while it waited (another group or user became active)
    // must not subscribe: its listeners would write the old group into the new state.
    bool stale() => generation != _generation;
    _unwrap(await repo.sendStaleTrips(onlyUser: userId));
    if (stale()) return Completer<ListState>().future;

    // The four live lists. The first value of each arrives at once from a local
    // store; later values follow every change, my own writes included.
    List<Product>? products;
    List<Trip>? trips;
    List<Plan>? plans;
    List<Notice>? notices;
    var built = false;
    final loaded = Completer<void>();
    void changed() {
      if (stale()) return;
      if (products == null ||
          trips == null ||
          plans == null ||
          notices == null) {
        return;
      }
      if (!built) {
        if (!loaded.isCompleted) loaded.complete();
        return;
      }
      state = AsyncData(
        state.requireValue.withData(
          products: products!,
          trips: trips!,
          plans: plans!,
          notices: notices!,
        ),
      );
    }

    StreamSubscription<Result<List<T>>> listen<T>(
      Stream<Result<List<T>>> stream,
      void Function(List<T> value) take,
    ) => stream.listen((result) {
      switch (result) {
        case Ok(:final value):
          take(value);
          changed();
        case Failure(:final error):
          // Only a failed first load replaces the screen; later the data stays.
          if (!built) {
            if (!loaded.isCompleted) loaded.completeError(error);
          } else {
            ref.read(writeFailuresProvider.notifier).report();
          }
      }
    });

    subscriptions.addAll([
      listen(repo.watchProducts(), (v) => products = v),
      listen(repo.watchOpenTrips(), (v) => trips = v),
      listen(repo.watchPlans(), (v) => plans = v),
      listen(repo.watchNotices(userId), (v) => notices = v),
      repo.writeErrors.listen(
        (_) => ref.read(writeFailuresProvider.notifier).report(),
      ),
      repo.online.listen(
        (online) => ref.read(offlineProvider.notifier).set(!online),
      ),
    ]);
    await loaded.future;
    if (stale()) return Completer<ListState>().future;
    final session = await _session(repo, userId);
    if (stale()) return Completer<ListState>().future;
    // No await from here to the return: a change arriving later updates the state.
    built = true;
    final initial =
        ListState(
          userId: userId,
          mode: ref.read(lastModeProvider) ?? ListMode.buy,
          autoSendAt: ref.read(idleDeadlinesProvider)[_idleKey(userId)],
          newSince: session.newSince,
          askedAt: session.askedAt,
        ).withData(
          products: products!,
          trips: trips!,
          plans: plans!,
          notices: notices!,
        );
    // Unsent marks mean a shopping trip is going on: open in Shop.
    return (initial.hasUnsent ? initial.copyWith(mode: ListMode.buy) : initial)
        .copyWith(rankFrequent: true);
  }

  /// What a visit knows besides the lists: where "New" starts and the last "Notify".
  Future<({DateTime? newSince, DateTime? askedAt})> _session(
    ListRepository repo,
    String userId,
  ) async => (
    newSince: ref.read(visitTrackerProvider).enter(_groupId, userId),
    askedAt: _unwrap(await repo.getAskedAt(userId)),
  );

  String get _groupId => ref.read(activeGroupIdProvider)!;

  String _idleKey(String userId) => '$_groupId/$userId';

  /// Restarts the idle countdown after a trip action (a mark added or removed);
  /// stops it when the user has no marks left. Other edits of the list do not count.
  void _restartIdleTimer(String userId, {required bool hasMarks}) {
    final timers = ref.read(idleTimersProvider);
    final key = _idleKey(userId);
    timers.remove(key)?.cancel();
    final deadlines = ref.read(idleDeadlinesProvider);
    deadlines.remove(key);
    final delay = ref.read(autoNotifyDelayProvider);
    final groupId = _groupId;
    final repo = ref.read(listRepositoryForProvider(groupId));
    if (!hasMarks || delay == null) {
      state = AsyncData(state.requireValue.copyWith(clearAutoSend: true));
      unawaited(repo.setAutoSendAt(userId, null));
      return;
    }
    final deadline = DateTime.now().add(delay);
    // The server's copy of the deadline: if this phone is dead by then, the server sends
    // the trip. The grace lets the phone's own timer go first when it is alive.
    unawaited(repo.setAutoSendAt(userId, deadline.add(serverSendGrace)));
    deadlines[key] = deadline;
    state = AsyncData(state.requireValue.copyWith(autoSendAt: deadline));
    timers[key] = Timer(delay, () => _sendIdleTrip(groupId, userId));
  }

  /// Sends the idle trip of [groupId], which may not be the group shown now.
  Future<void> _sendIdleTrip(String groupId, String userId) async {
    ref.read(idleTimersProvider).remove('$groupId/$userId');
    ref.read(idleDeadlinesProvider).remove('$groupId/$userId');
    // Signed out or switched to another user since the mark: nothing to send.
    if (userId != ref.read(currentUserIdProvider)) return;
    if (groupId == ref.read(activeGroupIdProvider)) {
      await _apply((repo) => repo.sendTrip(userId));
    } else {
      await ref.read(listRepositoryForProvider(groupId)).sendTrip(userId);
    }
  }

  /// Group sheet: shows the lists of another group; mode and search start over.
  void selectGroup(String groupId) =>
      ref.read(selectedGroupIdProvider.notifier).select(groupId);

  T _unwrap<T>(Result<T> result) => switch (result) {
    Ok(:final value) => value,
    Failure(:final error) => throw error,
  };

  Future<void> _apply(
    Future<Result<Object?>> Function(ListRepository repo) action, {
    String? Function()? flashId,
    String? pendingFlashId,
  }) async {
    final repo = ref.read(listRepositoryProvider);
    // The write is applied locally when the call returns and shows through the live
    // lists; nothing here waits for the server. A refusal comes later, see `build`.
    final result = await action(repo);
    if (result case Failure()) {
      ref.read(writeFailuresProvider.notifier).report();
      return;
    }
    if (!ref.mounted || !state.hasValue) return;
    state = AsyncData(
      state.requireValue.copyWith(
        clearFlash: true,
        flashId: flashId?.call(),
        pendingFlashId: pendingFlashId,
      ),
    );
  }

  /// The blink of the new product has ended.
  void clearFlash() {
    if (!state.hasValue || state.requireValue.flashId == null) return;
    state = AsyncData(state.requireValue.copyWith(clearFlash: true));
  }

  /// The Shop search closes with the switch.
  void setMode(ListMode mode) {
    ref.read(lastModeProvider.notifier).select(mode);
    final current = state.requireValue;
    state = AsyncData(
      current.copyWith(
        mode: mode,
        query: '',
        finding: false,
        clearFlash: true,
        // Coming to Shop ranks the Frequent card again; staying keeps it.
        rankFrequent: mode == ListMode.buy && current.mode != ListMode.buy,
      ),
    );
  }

  /// The app came back after a long pause (it left sight at [leftAt]): the session ends,
  /// so "New" is counted from this new start, and the Frequent card is ranked again.
  Future<void> startNewVisit(DateTime leftAt) async {
    ref.read(visitTrackerProvider).end(ref.read(currentUserIdProvider), leftAt);
    if (!state.hasValue) return;
    await refresh();
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(rankFrequent: true));
  }

  /// Opens or closes the Shop search; closing shows the product activated meanwhile.
  void setFinding(bool finding) {
    final current = state.requireValue;
    final ended = !finding && current.pendingFlashId != null;
    state = AsyncData(
      current.copyWith(
        finding: finding,
        query: '',
        flashId: ended ? current.pendingFlashId : null,
        clearPending: ended,
      ),
    );
  }

  /// Ending the search regroups the list: the product activated meanwhile blinks then.
  void setQuery(String query) {
    final current = state.requireValue;
    final ended =
        query.trim().isEmpty &&
        current.pendingFlashId != null &&
        !current.finding;
    state = AsyncData(
      current.copyWith(
        query: query,
        flashId: ended ? current.pendingFlashId : null,
        clearPending: ended,
      ),
    );
  }

  /// While searching, rows stay where they are and show the new state in place; the
  /// product blinks when the search ends. [flash] blinks it right away.
  Future<void> tap(Product product, {bool flash = false}) async {
    final userId = ref.read(currentUserIdProvider);
    final current = state.requireValue;
    // The partner's mark is read-only; only its author can remove it.
    if (current.mode == ListMode.buy &&
        current.partnerMarkIds.contains(product.id)) {
      return;
    }
    // A marked product is bought: Need does not change it either, or its mark would
    // hide and come back later. A mark is removed in Bought.
    if (current.mode == ListMode.need &&
        current.markOf(product.id) != RowMark.none) {
      return;
    }
    final becomesActive = current.mode == ListMode.buy
        ? !current.myMarkIds.contains(product.id)
        : !product.planned;
    await _apply(
      (repo) => switch (current.mode) {
        ListMode.buy => repo.toggleMark(product.id, userId),
        ListMode.need => repo.setPlanned(product, !product.planned, userId),
      },
      flashId: flash ? () => product.id : null,
      pendingFlashId: !flash && becomesActive && current.flatList
          ? product.id
          : null,
    );
    if (current.mode == ListMode.buy) {
      // Judged from the state before the tap: the live list may not show it yet.
      _restartIdleTimer(
        userId,
        hasMarks: becomesActive || current.myMarkIds.length > 1,
      );
    }
  }

  /// Shop: takes the needed products of one card that nobody has taken yet; the
  /// partner's marks stay.
  /// Returns the ids it marked, so the action can be undone.
  Future<List<String>> markAll(List<Product> card) async {
    final userId = ref.read(currentUserIdProvider);
    final ids = [for (final p in state.requireValue.untakenOf(card)) p.id];
    if (ids.isEmpty) return ids;
    await _apply((repo) => repo.setMarks(ids, userId, marked: true));
    _restartIdleTimer(userId, hasMarks: true);
    return ids;
  }

  Future<void> undoMarkAll(List<String> ids) async {
    final userId = ref.read(currentUserIdProvider);
    final left = {...state.requireValue.myMarkIds}..removeAll(ids);
    await _apply((repo) => repo.setMarks(ids, userId, marked: false));
    _restartIdleTimer(userId, hasMarks: left.isNotEmpty);
  }

  /// Moves a product inside [group], the rows of one list as shown (the whole Plan list
  /// or the To buy card, without the "New" group); other slots keep their place.
  Future<void> reorder({
    required List<Product> group,
    required int oldIndex,
    required int newIndex,
  }) {
    final s = state.requireValue;
    if (!s.canReorder) return Future.value();
    final moved = [...group];
    final product = moved.removeAt(oldIndex);
    moved.insert(newIndex, product);
    // One write: the product goes between the rows that are now above and below it.
    return _apply(
      (repo) => repo.moveProduct(
        product.id,
        above: newIndex > 0 ? moved[newIndex - 1].id : null,
        below: newIndex < moved.length - 1 ? moved[newIndex + 1].id : null,
      ),
    );
  }

  /// Renames [product]. Returns what is wrong with [raw] (nothing is saved then), or null
  /// when the name was saved. The name may differ from the old one only in letter case.
  Future<NameProblem?> renameProduct(Product product, String raw) async {
    final check = ProductNames.check(
      raw,
      state.requireValue.products,
      selfId: product.id,
    );
    if (!check.ok) return check.problem;
    if (check.name != product.name) {
      await _apply((repo) => repo.renameProduct(product, check.name));
    }
    return null;
  }

  /// Takes [product] out of the lists (it goes to the archive); the user's own mark of
  /// it goes too. [undoDeleteProduct] brings it back.
  Future<void> deleteProduct(Product product) async {
    final userId = ref.read(currentUserIdProvider);
    final s = state.requireValue;
    final marked = s.myMarkIds.contains(product.id);
    await _apply((repo) => repo.deleteProduct(product, userId));
    if (marked) {
      _restartIdleTimer(userId, hasMarks: s.myMarkIds.length > 1);
    }
  }

  /// Undo of [deleteProduct]: [product] as it was before comes back.
  Future<void> undoDeleteProduct(Product product) {
    final userId = ref.read(currentUserIdProvider);
    return _apply((repo) => repo.undeleteProduct(product, userId));
  }

  /// Brings an archived product back under [raw]. Returns what is wrong with the name
  /// (a product of the list already has it), or null when it is back.
  Future<NameProblem?> restoreProduct(Product archived, String raw) async {
    final check = ProductNames.check(raw, state.requireValue.products);
    if (!check.ok) return check.problem;
    await _apply((repo) => repo.restoreProduct(archived, check.name));
    return null;
  }

  /// Returns how many products became needed (those already needed do not count).
  Future<int> applyPlan(Plan plan) async {
    final userId = ref.read(currentUserIdProvider);
    final added = state.requireValue.products
        .where((p) => plan.productIds.contains(p.id) && !p.planned)
        .length;
    await _apply((repo) => repo.applyPlan(plan, userId));
    return added;
  }

  Future<void> togglePinned(Plan plan) =>
      _apply((repo) => repo.setPinned(plan, !plan.pinned));

  Future<void> deletePlan(Plan plan) => _apply((repo) => repo.deletePlan(plan));

  Future<void> restorePlan(Plan plan) =>
      _apply((repo) => repo.restorePlan(plan));

  Future<void> sortBy(SortKey key) => _apply((repo) => repo.sortBy(key));

  /// Enter in the search field: activates the only match (plans it in Need, marks it in
  /// Bought). Search never creates products. Returns false when there was no single match.
  Future<bool> activateQuery() async {
    final current = state.requireValue;
    if (!current.searching) return false;
    final target =
        current.exactMatch ??
        (current.visible.length == 1 ? current.visible.single : null);
    if (target == null) return false;
    setQuery('');
    final active = current.mode == ListMode.buy
        ? current.markOf(target.id) != RowMark.none
        : target.planned;
    // The filter is gone now, so even an already active row is shown to the user.
    if (active) {
      await _apply(
        (repo) async => const Ok<void>(null),
        flashId: () => target.id,
      );
    } else {
      await tap(target, flash: true);
    }
    return true;
  }

  /// Plan: creates a needed product at the top of the list. Shop: creates it taken
  /// (a spontaneous purchase) and not planned. An existing name is not duplicated, its
  /// row just gets the scroll and blink.
  Future<void> addProduct(String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) return;
    final current = state.requireValue;
    final shop = current.mode == ListMode.buy;
    final userId = ref.read(currentUserIdProvider);
    final existing = current.products
        .where((p) => p.name.toLowerCase() == name.toLowerCase())
        .firstOrNull;
    if (existing != null) {
      await _apply(
        (repo) async => const Ok<void>(null),
        flashId: () => existing.id,
      );
      return;
    }
    String? addedId;
    await _apply((repo) async {
      final added = await repo.addProduct(
        name,
        planned: !shop,
        atStart: true,
        userId: userId,
      );
      if (added case Ok(:final value)) addedId = value.id;
      return switch (added) {
        Ok(:final value) when shop => await repo.toggleMark(value.id, userId),
        Ok() => const Ok<void>(null),
        Failure(:final error) => Failure<void>(error),
      };
    }, flashId: () => addedId);
    if (shop) _restartIdleTimer(userId, hasMarks: true);
  }

  /// "Add products": makes the names needed, see [ListRepository.addProducts]. Returns
  /// how many products changed.
  Future<int> addProducts(List<String> names) async {
    var changed = 0;
    final userId = ref.read(currentUserIdProvider);
    await _apply((repo) async {
      final result = await repo.addProducts(names, userId);
      if (result case Ok(:final value)) changed = value;
      return result;
    });
    return changed;
  }

  /// Plan "Ask": tells the group about my products nobody has taken. Returns how many
  /// were announced.
  Future<int> ask() async {
    var count = 0;
    final userId = ref.read(currentUserIdProvider);
    final ids = [for (final p in state.requireValue.askProducts) p.id];
    await _apply((repo) async {
      final result = await repo.ask(userId, ids);
      if (result case Ok(:final value)) {
        count = value;
        // The time of this Ask decides which products the next one announces. It is
        // "now" here: the server stamps the stored value later, and a read right after
        // the write may not see it yet.
        if (count > 0 && state.hasValue) {
          state = AsyncData(
            state.requireValue.withSession(
              newSince: state.requireValue.newSince,
              askedAt: DateTime.now(),
            ),
          );
        }
      }
      return result;
    });
    return count;
  }

  /// Debug menu: acts as another user of the group on the same phone.
  Future<void> selectUser(String userId) {
    // Leaving a user ends their session, so coming back counts what the other added.
    ref
        .read(visitTrackerProvider)
        .end(ref.read(currentUserIdProvider), DateTime.now());
    ref.read(userSlotProvider.notifier).select(userId);
    // The list is built again for the new user.
    return future.then((_) {});
  }

  Future<void> dismissNotices() {
    final userId = ref.read(currentUserIdProvider);
    return _apply((repo) => repo.markNoticesSeen(userId));
  }

  /// Marks the notices that came more than [age] ago as seen; newer ones stay.
  Future<void> dismissNoticesOlderThan(Duration age) {
    final userId = ref.read(currentUserIdProvider);
    final before = DateTime.now().subtract(age);
    return _apply((repo) => repo.markNoticesSeen(userId, sentBefore: before));
  }

  /// A notice nobody read for this long is not news any more.
  static const noticeLifetime = Duration(hours: 24);

  /// The lists are live and need no reload. This does the checks of a visit: sends a
  /// trip left from a past day, and counts "New" and the last "Notify" again.
  Future<void> refresh() async {
    await future;
    final repo = ref.read(listRepositoryProvider);
    _unwrap(
      await repo.sendStaleTrips(onlyUser: ref.read(currentUserIdProvider)),
    );
    // An old notice does not hang in the banner for ever (a failure changes nothing).
    await repo.markNoticesSeen(
      ref.read(currentUserIdProvider),
      sentBefore: DateTime.now().subtract(noticeLifetime),
    );
    final session = await _session(repo, ref.read(currentUserIdProvider));
    if (!ref.mounted || !state.hasValue) return;
    state = AsyncData(
      state.requireValue.withSession(
        newSince: session.newSince,
        askedAt: session.askedAt,
      ),
    );
  }

  /// Notify: sends my trip and closes it. Returns how many products were sent.
  Future<int> notify() async {
    var count = 0;
    final userId = ref.read(currentUserIdProvider);
    ref.read(idleTimersProvider).remove(_idleKey(userId))?.cancel();
    ref.read(idleDeadlinesProvider).remove(_idleKey(userId));
    await _apply((repo) async {
      final result = await repo.sendTrip(userId);
      if (result case Ok(:final value)) count = value;
      return result;
    });
    return count;
  }
}

final listViewModelProvider = AsyncNotifierProvider<ListViewModel, ListState>(
  ListViewModel.new,
);
