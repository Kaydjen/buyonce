import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/result.dart';
import '../../../data/repositories/list_repository.dart';
import '../../../domain/models/plan.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/sort_key.dart';
import '../groups/groups_view_model.dart';
import '../session/session.dart';
import '../settings/settings_view_model.dart';
import 'list_state.dart';

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
final idleDeadlinesProvider = Provider<Map<String, DateTime>>((_) => {});

class ListViewModel extends AsyncNotifier<ListState> {
  @override
  Future<ListState> build() async {
    // Switching auto-send off stops the running countdowns; a new period only
    // applies from the next mark.
    ref.listen(autoNotifyDelayProvider, (_, delay) {
      if (delay != null) return;
      final timers = ref.read(idleTimersProvider);
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
    final loaded = await _load(
      ref.watch(listRepositoryProvider),
      ListState(mode: ref.read(lastModeProvider) ?? ListMode.buy),
    );
    // Unsent marks mean a shopping trip is going on: open in Shop.
    return (loaded.hasUnsent ? loaded.copyWith(mode: ListMode.buy) : loaded)
        .copyWith(rankFrequent: true);
  }

  String get _groupId => ref.read(activeGroupIdProvider)!;

  String _idleKey(String userId) => '$_groupId/$userId';

  /// Restarts the idle countdown after a trip action (a mark added or removed);
  /// stops it when the user has no marks left. Other edits of the list do not count.
  void _restartIdleTimer(String userId) {
    final timers = ref.read(idleTimersProvider);
    final key = _idleKey(userId);
    timers.remove(key)?.cancel();
    final deadlines = ref.read(idleDeadlinesProvider);
    deadlines.remove(key);
    final delay = ref.read(autoNotifyDelayProvider);
    final hasMarks = state.requireValue.trips.any(
      (t) => t.userId == userId && t.marks.isNotEmpty,
    );
    if (!hasMarks || delay == null) {
      state = AsyncData(state.requireValue.copyWith(clearAutoSend: true));
      return;
    }
    final groupId = _groupId;
    final deadline = DateTime.now().add(delay);
    deadlines[key] = deadline;
    state = AsyncData(state.requireValue.copyWith(autoSendAt: deadline));
    timers[key] = Timer(delay, () => _sendIdleTrip(groupId, userId));
  }

  /// Sends the idle trip of [groupId], which may not be the group shown now.
  Future<void> _sendIdleTrip(String groupId, String userId) async {
    ref.read(idleTimersProvider).remove('$groupId/$userId');
    ref.read(idleDeadlinesProvider).remove('$groupId/$userId');
    if (groupId == ref.read(activeGroupIdProvider)) {
      await _apply((repo) => repo.sendTrip(userId));
    } else {
      await ref.read(listRepositoryForProvider(groupId)).sendTrip(userId);
    }
  }

  /// Group sheet: shows the lists of another group; mode and search start over.
  void selectGroup(String groupId) =>
      ref.read(selectedGroupIdProvider.notifier).select(groupId);

  Future<ListState> _load(
    ListRepository repo,
    ListState base, {
    String? flashId,
    String? pendingFlashId,
  }) async {
    _unwrap(await repo.sendStaleTrips());
    final products = _unwrap(await repo.getProducts());
    final trips = _unwrap(await repo.getOpenTrips());
    final plans = _unwrap(await repo.getPlans());
    final usage = _unwrap(await repo.getUsage());
    final userId = ref.read(currentUserIdProvider);
    final notices = _unwrap(await repo.getNotices(userId));
    return ListState(
      products: products,
      trips: trips,
      userId: userId,
      notices: notices,
      plans: plans,
      usage: usage,
      mode: base.mode,
      query: base.query,
      finding: base.finding,
      autoSendAt: ref.read(idleDeadlinesProvider)[_idleKey(userId)],
      flashId: flashId,
      pendingFlashId: pendingFlashId ?? base.pendingFlashId,
      frequentIds: base.frequentIds,
      newSince: ref.read(visitTrackerProvider).enter(_groupId, userId),
      askedAt: _unwrap(await repo.getAskedAt(userId)),
    );
  }

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
    state = await AsyncValue.guard(() async {
      _unwrap(await action(repo));
      return _load(
        repo,
        state.requireValue,
        flashId: flashId?.call(),
        pendingFlashId: pendingFlashId,
      );
    });
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
    if (current.mode == ListMode.buy) _restartIdleTimer(userId);
  }

  /// Shop: takes the needed products of one card that nobody has taken yet; the
  /// partner's marks stay.
  /// Returns the ids it marked, so the action can be undone.
  Future<List<String>> markAll(List<Product> card) async {
    final userId = ref.read(currentUserIdProvider);
    final ids = [for (final p in state.requireValue.untakenOf(card)) p.id];
    if (ids.isEmpty) return ids;
    await _apply((repo) => repo.setMarks(ids, userId, marked: true));
    _restartIdleTimer(userId);
    return ids;
  }

  Future<void> undoMarkAll(List<String> ids) async {
    final userId = ref.read(currentUserIdProvider);
    await _apply((repo) => repo.setMarks(ids, userId, marked: false));
    _restartIdleTimer(userId);
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
    final inGroup = {for (final p in group) p.id};
    final moved = [...group];
    moved.insert(newIndex, moved.removeAt(oldIndex));
    var next = 0;
    final ids = [
      for (final p in s.products)
        inGroup.contains(p.id) ? moved[next++].id : p.id,
    ];
    return _apply((repo) => repo.reorder(ids));
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
    if (shop) _restartIdleTimer(userId);
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
      if (result case Ok(:final value)) count = value;
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
    ref.read(currentUserIdProvider.notifier).select(userId);
    return refresh();
  }

  Future<void> dismissNotices() {
    final userId = ref.read(currentUserIdProvider);
    return _apply((repo) => repo.markNoticesSeen(userId));
  }

  /// Reloads the lists, for example after the partner's marks changed.
  Future<void> refresh() => _apply((repo) async => const Ok<void>(null));

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
