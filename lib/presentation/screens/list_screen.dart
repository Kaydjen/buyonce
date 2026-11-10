import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/clip.dart';
import '../../domain/models/group.dart';
import '../../domain/models/product.dart';
import '../../domain/models/product_names.dart';
import '../../l10n/l10n.dart';
import '../view_models/account/account_view_model.dart';
import '../view_models/groups/groups_view_model.dart';
import '../view_models/list/list_state.dart';
import '../view_models/list/list_view_model.dart';
import '../view_models/list/sync_state.dart';
import '../view_models/session/session.dart';
import '../view_models/update/update_view_model.dart';
import '../view_models/users/user_names_view_model.dart';
import '../widgets/accent_dot.dart';
import '../widgets/card_action.dart';
import '../widgets/card_menu.dart';
import '../widgets/card_title.dart';
import '../widgets/debug_user_sheet.dart';
import '../widgets/edge_fade.dart';
import '../widgets/flash_on_add.dart';
import '../widgets/group_dialogs.dart';
import '../widgets/group_sheet.dart';
import '../widgets/haptics.dart';
import '../widgets/inset.dart';
import '../widgets/load_failed.dart';
import '../widgets/mode_bar.dart';
import '../widgets/notice_banner.dart';
import '../widgets/panel.dart';
import '../widgets/plain_button.dart';
import '../widgets/plans_sheet.dart';
import '../widgets/product_row.dart';
import '../widgets/card_dialog.dart';
import '../widgets/raised_icon.dart';
import '../widgets/row_menu.dart';
import '../widgets/send_button.dart';
import '../widgets/sign_in_prompt.dart';
import '../widgets/sort_sheet.dart';
import '../widgets/toast.dart';
import '../widgets/top_bar.dart';
import '../view_models/list/archive_view_model.dart';
import 'add_products_screen.dart';
import 'archive_screen.dart';
import 'group_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class ListScreen extends ConsumerStatefulWidget {
  const ListScreen({super.key});

  @override
  ConsumerState<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends ConsumerState<ListScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _scroll = ScrollController();
  final _frequentKey = GlobalKey();
  final _selectKey = GlobalKey();

  /// The product whose row shows the long-press menu and the drag handle; one at a time.
  String? _menuId;
  OverlayEntry? _menuEntry;
  final _menuLink = LayerLink();
  final _menuGroup = Object();

  final _barKey = GlobalKey();
  final _stackKey = GlobalKey();
  final _statusKey = GlobalKey();
  final _findKey = GlobalKey();

  /// Where the card button sits in its card: distance from the right edge and from the
  /// top, as last measured (the field replaces the button while a search is open).
  Offset _homeInCard = const Offset(29, 28);

  /// The plate the icon starts from (the card button).
  static const _plate = 38.0;

  /// How far the icon has glided from the card to the bar slot, 0..1. It runs on its own
  /// spring once the icon leaves the card, so it always arrives, however far the list is
  /// scrolled; a faster scroll starts it faster.
  late final AnimationController _glide = AnimationController.unbounded(
    vsync: this,
  );
  bool _docked = false;

  /// The icon is drawn by the overlay: the button in the card is hidden meanwhile.
  final _overlayOn = ValueNotifier<bool>(false);

  /// Last measured position of the card button, for a card that is not built.
  Offset? _lastHome;

  /// Scroll speed in dp/s, from the last two offsets that differed.
  double _scrollSpeed = 0;
  double _prevOffset = 0;
  final _clock = Stopwatch()..start();
  Duration _prevAt = Duration.zero;

  /// The docked search icon would cover the "N to buy" status (a narrow phone or large
  /// text): the status gives way. Changes only when it flips.
  final _hideStatus = ValueNotifier<bool>(false);

  /// Global right edge of the status while it was last shown.
  double _statusRight = 0;

  /// Plan: the search field is open in the list card. Shop keeps this in the view model.
  bool _planFind = false;

  /// The confirmation shown on the Send / Notify button for a moment after it.
  ({bool ask, String text})? _sent;
  Timer? _sentTimer;

  /// The text of the presence strip the user has tapped away.
  String? _presenceHidden;
  double _lastKeyboardInset = 0;
  DateTime? _pausedAt;
  static const _noticeReadTime = Duration(seconds: 10);

  /// Away from the app this long counts as a new visit: Frequent is ranked again and
  /// the "New" group is counted from the start of the visit.
  static const _newVisit = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_updateDock);
    _scroll.addListener(_closeMenuOnScroll);
    _glide.addListener(_updateDock);
  }

  /// Scrolling the list closes the row menu (its anchor moves away).
  void _closeMenuOnScroll() {
    if (_menuEntry != null) _closeMenu();
  }

  /// The laid-out box of a keyed widget, or null when it is not built, not laid out yet
  /// or being removed (a key can outlive its element for a frame).
  RenderBox? _boxOf(GlobalKey key) {
    try {
      final box = key.currentContext?.findRenderObject();
      return box is RenderBox && box.attached && box.hasSize ? box : null;
    } catch (_) {
      return null;
    }
  }

  /// Where the search icon would be on its card and where the bar slot is (global),
  /// and how far the card button is past the top edge of the list ([away] > 0: its plate
  /// starts to be cut). Null while not measurable (first frame, no list yet).
  ({double away, Offset home, Offset slot})? _measure() {
    final s = ref.read(listViewModelProvider).value;
    final bar = _boxOf(_barKey);
    final list = _scroll.hasClients
        ? _scroll.position.context.storageContext.findRenderObject()
        : null;
    if (s == null || bar == null || list is! RenderBox || !list.hasSize) {
      return null;
    }
    final t = context.tokens;
    final shop = s.mode == ListMode.buy;
    final iconWidth = t.depth > 0 ? 52.0 : 48.0;
    final barBox = bar.localToGlobal(Offset.zero) & bar.size;
    final slot = Offset(
      barBox.right - 4 - iconWidth * (shop ? 1 : 2) - iconWidth / 2,
      barBox.center.dy,
    );
    final listTop = list.localToGlobal(Offset.zero).dy;
    final card = _boxOf(shop ? _frequentKey : _selectKey);
    if (card == null) {
      // A card that is not built is far above the list once the list is scrolled.
      return _scroll.offset > 0
          ? (away: 1000, home: _lastHome ?? slot, slot: slot)
          : null;
    }
    // The card top from the live scroll offset, not from the last layout, which is one
    // frame behind while the list moves.
    double reveal;
    try {
      reveal = RenderAbstractViewport.of(card)
          .getOffsetToReveal(card, 0)
          .offset;
    } catch (_) {
      // The list has not been laid out yet (the first frame of a new list).
      return null;
    }
    final cardTop = Offset(
      card.localToGlobal(Offset.zero).dx,
      listTop + reveal - _scroll.offset,
    );
    final button = _boxOf(_findKey);
    if (button != null) {
      final centre = button.localToGlobal(button.size.center(Offset.zero));
      final top = card.localToGlobal(Offset.zero);
      _homeInCard = Offset(
        top.dx + card.size.width - centre.dx,
        centre.dy - top.dy,
      );
    }
    final home = Offset(
      cardTop.dx + card.size.width - _homeInCard.dx,
      cardTop.dy + _homeInCard.dy,
    );
    // Where the icon leaves the card: the card itself may be far above (a fast scroll),
    // but the glide starts at the top edge of the list, never off the screen.
    final edge = listTop + _plate / 2;
    final start = Offset(home.dx, home.dy < edge ? edge : home.dy);
    _lastHome = start;
    return (away: edge - home.dy, home: start, slot: slot);
  }

  /// The mode the dock state was last set for; a change snaps instead of gliding.
  ListMode? _dockMode;

  /// Starts the glide when the icon leaves the card or comes back to it, and keeps the
  /// status out from under the docked icon; see [_hideStatus].
  void _updateDock() {
    if (!mounted) return;
    final status = _boxOf(_statusKey);
    if (status != null && !_hideStatus.value) {
      _statusRight = status.localToGlobal(Offset(status.size.width, 0)).dx;
    }
    if (_scroll.hasClients && _scroll.offset != _prevOffset) {
      final dt = (_clock.elapsed - _prevAt).inMicroseconds / 1e6;
      if (dt > 0) _scrollSpeed = (_scroll.offset - _prevOffset).abs() / dt;
      _prevOffset = _scroll.offset;
      _prevAt = _clock.elapsed;
    }
    final m = _measure();
    final want = m != null && m.away > 0;
    final mode = ref.read(listViewModelProvider).value?.mode;
    if (m != null && mode != _dockMode) {
      // A tab switch is a new screen: the icon is where it belongs at once, it does not
      // fly in from the place it had on the other tab.
      _dockMode = mode;
      _docked = want;
      _glide.stop();
      _glide.value = want ? 1 : 0;
    } else if (want != _docked) {
      _docked = want;
      // A fast scroll sends the icon off faster; a slow one lets it settle gently.
      final kick = (_scrollSpeed / 400).clamp(0.0, 6.0);
      _glide.animateWith(
        SpringSimulation(
          SpringDescription.withDampingRatio(mass: 1, stiffness: 260, ratio: 1),
          _glide.value,
          want ? 1 : 0,
          want ? kick : -kick,
        ),
      );
    }
    _overlayOn.value = m != null && (want || _glide.value > 0.001);
    final iconWidth = context.tokens.depth > 0 ? 52.0 : 48.0;
    _hideStatus.value =
        m != null &&
        (want || _glide.value > 0.5) &&
        _statusRight > m.slot.dx - iconWidth / 2 - 4;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
      // The user has read what was on this screen; a notice that came in the last
      // seconds may not have been seen and stays.
      if (ModalRoute.of(context)?.isCurrent ?? false) {
        ref
            .read(listViewModelProvider.notifier)
            .dismissNoticesOlderThan(_noticeReadTime);
      }
    } else if (state == AppLifecycleState.resumed) {
      final left = _pausedAt;
      _pausedAt = null;
      if (left != null && DateTime.now().difference(left) >= _newVisit) {
        ref.read(listViewModelProvider.notifier).startNewVisit(left);
      }
    }
  }

  /// Hiding the keyboard (system back, hide button) leaves the focus in the field, so
  /// the caret keeps blinking with nothing to type into. Drop the focus when the
  /// keyboard goes away; a tap on the field shows it again.
  @override
  void didChangeMetrics() {
    final view = View.maybeOf(context);
    if (view == null) return;
    final inset = view.viewInsets.bottom;
    final hidden = _lastKeyboardInset > 0 && inset == 0;
    _lastKeyboardInset = inset;
    if (hidden && _searchFocus.hasFocus) _searchFocus.unfocus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _menuEntry?.remove();
    _menuEntry = null;
    _sentTimer?.cancel();
    _searchFocus.dispose();
    _search.dispose();
    _scroll.dispose();
    _glide.dispose();
    _overlayOn.dispose();
    _hideStatus.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _search.clear();
    ref.read(listViewModelProvider.notifier).setQuery('');
  }

  /// The close icon of the field: it clears the query and gives the card its title back.
  void _closeField(ListState s) {
    _search.clear();
    final vm = ref.read(listViewModelProvider.notifier);
    if (s.mode == ListMode.buy) {
      vm.setFinding(false);
    } else {
      setState(() => _planFind = false);
      vm.setQuery('');
    }
  }

  /// The search icon of the Frequent card: the field replaces the title and the card
  /// scrolls to the top, so the keyboard never covers the results.
  ///
  /// [fromDock]: the icon in the top bar, used when the card is scrolled away. Plan then
  /// scrolls to the card too (the "New" card may sit above it), and an open field only
  /// gets the focus back.
  void _openFind({bool fromDock = false}) {
    final plan =
        ref.read(listViewModelProvider).requireValue.mode == ListMode.need;
    if (plan) {
      setState(() => _planFind = true);
    } else {
      ref.read(listViewModelProvider.notifier).setFinding(true);
    }
    if (plan && !fromDock) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final card = (plan ? _selectKey : _frequentKey).currentContext;
      if (card != null) {
        Scrollable.ensureVisible(
          card,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
      if (fromDock) _searchFocus.requestFocus();
    });
  }

  /// The search icon off its card: a plate that morphs from the low plate of the
  /// card to the raised one of the bar as it glides (see [_flightState]).
  Widget _dockOverlay() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: Listenable.merge([_scroll, _glide]),
        builder: (context, _) {
          final m = _measure();
          final stack = _boxOf(_stackKey);
          final g = _glide.value.clamp(0.0, 1.0);
          if (m == null || stack == null || (m.away <= 0 && g <= 0.001)) {
            return const SizedBox.shrink();
          }
          // The height follows the card until the icon has glided into the bar.
          final at = stack.globalToLocal(Offset.lerp(m.home, m.slot, g)!);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: at.dx - 24,
                top: at.dy - 24,
                width: 48,
                height: 48,
                child: _dockButton(g),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _dockButton(double p) {
    final t = context.tokens;
    final plate = t.depth > 0
        ? DecoratedBox(
            // The card button's own look at the start (so it does not change when the
            // icon leaves or lands), the lift of the bar icons at the end.
            decoration: cardPlateLook(
              t,
              BoxShape.circle,
              lift: lerpDouble(cardPlateLift, 0.6, p)!,
            ),
            child: SizedBox.square(
              dimension: _plate + (44 - _plate) * p,
              child: Icon(
                Icons.search,
                size: 20 + 2 * p,
                color: Color.lerp(t.muted, t.text, p),
              ),
            ),
          )
        : const Icon(Icons.search);
    return Tooltip(
      message: context.l10n.search,
      child: GestureDetector(
        key: const Key('findDock'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _openFind(fromDock: true),
        child: Center(child: plate),
      ),
    );
  }

  void _setMode(ListMode mode) {
    _search.clear();
    _planFind = false;
    // The two lists share one scroll view: each opens at its top, and an Undo of the
    // other mode does not linger.
    if (_scroll.hasClients) _scroll.jumpTo(0);
    ScaffoldMessenger.of(context).clearSnackBars();
    ref.read(listViewModelProvider.notifier).setMode(mode);
  }

  /// Enter in the field: activates the only match; with no match it adds the name.
  Future<void> _submit() async {
    final vm = ref.read(listViewModelProvider.notifier);
    if (await vm.activateQuery()) {
      _search.clear();
      // The product is taken: close the search so it shows in the list and blinks.
      if (ref.read(listViewModelProvider).requireValue.mode == ListMode.buy) {
        vm.setFinding(false);
      }
    } else if (ref.read(listViewModelProvider).requireValue.canAdd) {
      await _add(_search.text);
    }
  }

  /// The search ends first, so the new row is built once in the regrouped list. The
  /// list jumps to the top, where the new product lands; a row far off screen is never
  /// built, so it could neither scroll to itself nor blink.
  Future<void> _add(String name) async {
    _clearSearch();
    if (_scroll.hasClients) _scroll.jumpTo(0);
    final vm = ref.read(listViewModelProvider.notifier);
    await vm.addProduct(name);
    if (ref.read(listViewModelProvider).requireValue.mode == ListMode.buy) {
      vm.setFinding(false);
    }
  }

  /// The "Add products" screen; on return the list shows the new products from the top.
  Future<void> _addProducts() async {
    final changed = await Navigator.of(
      context,
    ).push<int>(MaterialPageRoute(builder: (_) => const AddProductsScreen()));
    if (!mounted || changed == null || changed == 0) return;
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
    showToast(context, context.l10n.addedCount(changed));
  }

  /// Takes everything still open; the snackbar can take it back.
  Future<void> _markAll(List<Product> card) async {
    final vm = ref.read(listViewModelProvider.notifier);
    final ids = await vm.markAll(card);
    if (!mounted || ids.isEmpty) return;
    showToast(
      context,
      context.l10n.markedCount(ids.length),
      actionLabel: context.l10n.undo,
      onAction: () => vm.undoMarkAll(ids),
    );
  }

  Future<void> _notify() async {
    Haptics.send(context);
    final l10n = context.l10n;
    String word(int n) => _isPersonal ? l10n.doneCount(n) : l10n.sentCount(n);
    // The confirmation appears with the press, not after the answer: the marks leave the
    // state at once, and the button would start to slide out before it could confirm.
    final expected =
        ref.read(listViewModelProvider).value?.myMarkIds.length ?? 0;
    _confirmSent(ask: false, text: word(expected), count: expected);
    final count = await ref.read(listViewModelProvider.notifier).notify();
    if (!mounted) return;
    if (count == 0) {
      _clearSent();
    } else if (count != expected) {
      _confirmSent(ask: false, text: word(count), count: count);
    }
  }

  /// The button that was pressed says what happened for two seconds, then goes.
  void _confirmSent({
    required bool ask,
    required String text,
    required int count,
  }) {
    if (count == 0) return;
    _sentTimer?.cancel();
    setState(() => _sent = (ask: ask, text: text));
    _sentTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _sent = null);
    });
  }

  Future<void> _ask() async {
    Haptics.send(context);
    final expected =
        ref.read(listViewModelProvider).value?.askProducts.length ?? 0;
    _confirmSent(
      ask: true,
      text: context.l10n.notifiedCount(expected),
      count: expected,
    );
    final count = await ref.read(listViewModelProvider.notifier).ask();
    if (!mounted) return;
    if (count == 0) {
      _clearSent();
    } else if (count != expected) {
      _confirmSent(
        ask: true,
        text: context.l10n.notifiedCount(count),
        count: count,
      );
    }
  }

  void _clearSent() {
    _sentTimer?.cancel();
    setState(() => _sent = null);
  }

  /// A tap on a product that is already taken: a short note at the bottom, it goes
  /// away by itself and replaces an earlier one instead of piling up.
  void _hintTaken(String text) {
    showToast(context, text, duration: const Duration(seconds: 2));
  }

  /// Debug builds only: long press on the group name switches the user.
  Future<void> _debugUser(String current) async {
    final id = await showDebugUserSheet(context, current);
    if (id == null || !mounted) return;
    await ref.read(listViewModelProvider.notifier).selectUser(id);
  }

  /// Names are shown only once they are known (or failed to load), so a cold start from
  /// a push never flashes "Member" instead of the sender.
  bool get _namesReady {
    final names = ref.watch(userNamesProvider);
    return names.hasValue || names.hasError;
  }

  List<String> _noticeLines(ListState s) => !_namesReady
      ? const []
      : noticeLines(
          s.notices,
          s.products,
          (userId) => ref.watch(userNameProvider(userId)),
          l10n: context.l10n,
        );

  bool get _signedIn => ref.read(accountViewModelProvider).value != null;

  Future<void> _switchGroup() async {
    final current = ref.read(activeGroupIdProvider)!;
    final choice = await showGroupSheet(context, current);
    if (choice == null || !mounted) return;
    switch (choice) {
      case SwitchGroup(:final groupId):
        if (groupId == current) return;
        _search.clear();
        ref.read(listViewModelProvider.notifier).selectGroup(groupId);
      case NewGroup():
        await (_signedIn
            ? showCreateGroupDialog(context, ref)
            : showSignInRequired(context, ref));
        _search.clear();
      case JoinGroup():
        await (_signedIn
            ? showJoinGroupDialog(context, ref)
            : showSignInRequired(context, ref));
        _search.clear();
      case GroupSettings():
        await Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => GroupScreen(groupId: current)),
        );
    }
  }

  Future<void> _sort() async {
    final key = await showSortSheet(context);
    if (key == null) return;
    await ref.read(listViewModelProvider.notifier).sortBy(key);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(listViewModelProvider);
    final vm = ref.read(listViewModelProvider.notifier);
    // Kept alive for the menu: "Archive" shows only while something is deleted.
    ref.watch(archivedProductsProvider);
    final float = context.tokens.floatTabs;
    // While another group loads the old one's controls are gone, not tappable.
    final ready = async.hasValue && !async.isLoading;
    // A write that was shown and then refused: the list is back to the real data.
    ref.listen(
      writeFailuresProvider,
      (_, _) => showToast(context, context.l10n.couldntSave),
    );
    // Another group became active (push tap, removal): the old search is gone.
    ref.listen(activeGroupIdProvider, (_, _) {
      _search.clear();
      _planFind = false;
    });
    final s = async.value;
    final searchOpen =
        s != null &&
        (s.mode == ListMode.buy ? s.finding : (_planFind || s.searching));
    // Back closes an open search first, then leaves.
    return PopScope(
      canPop: !searchOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && s != null) _closeField(s);
      },
      child: Scaffold(
        body: Stack(
          children: [
            // The levitating switcher lets the list run under the bottom inset, so the
            // shadows of the cards are not cut by a line above the system buttons.
            SafeArea(
              bottom: !float,
              child: switch (async) {
                AsyncData(:final value) => _content(value, vm),
                AsyncError() => LoadFailed(
                  onRetry: () => ref.invalidate(listViewModelProvider),
                ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
            if (float && ready)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ModeBar(
                  mode: async.requireValue.mode,
                  onSelect: _setMode,
                ),
              ),
          ],
        ),
        // Above the levitating switcher when there is one.
        floatingActionButton: ready
            ? Padding(
                padding: EdgeInsets.only(
                  bottom: float ? context.tokens.floatLift : 0,
                ),
                child: _sendButton(async.requireValue),
              )
            : null,
        bottomNavigationBar: !float && ready
            ? ModeBar(mode: async.requireValue.mode, onSelect: _setMode)
            : null,
      ),
    );
  }

  /// The menu icon; a small dot says a newer version can be installed.
  Widget _menuIcon() {
    final hasUpdate = ref.watch(
      updateViewModelProvider.select((u) => u.hasUpdate),
    );
    if (!hasUpdate) return const Icon(Icons.more_vert);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.more_vert),
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            key: const Key('updateDot'),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: context.tokens.text,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }

  bool get _isPersonal =>
      ref
          .watch(groupsViewModelProvider)
          .value
          ?.any(
            (g) => g.id == ref.watch(activeGroupIdProvider) && g.personal,
          ) ??
      false;

  /// Plan "Ask" needs someone to ask: a group with another member.
  bool get _hasPartners =>
      ref
          .watch(groupsViewModelProvider)
          .value
          ?.any(
            (g) =>
                g.id == ref.watch(activeGroupIdProvider) &&
                !g.personal &&
                g.memberIds.length > 1,
          ) ??
      false;

  /// Floating action buttons, so a snackbar pushes them up instead of covering them.
  /// Shop has Send, Plan has Ask; one shows at a time.
  Widget _sendButton(ListState s) => Stack(
    alignment: Alignment.bottomRight,
    children: [
      SendButton(
        visible: s.mode == ListMode.buy && s.hasUnsent,
        confirmed: s.mode == ListMode.buy && _sent?.ask == false
            ? _sent!.text
            : null,
        count: s.myMarkIds.length,
        autoSendAt: s.autoSendAt,
        onSend: _notify,
        label: _isPersonal ? context.l10n.done : context.l10n.send,
      ),
      SendButton(
        buttonKey: const Key('askButton'),
        visible:
            s.mode == ListMode.need && s.askProducts.isNotEmpty && _hasPartners,
        confirmed: s.mode == ListMode.need && _sent?.ask == true
            ? _sent!.text
            : null,
        count: s.askProducts.length,
        autoSendAt: null,
        onSend: _ask,
        label: context.l10n.notify,
      ),
    ],
  );

  Widget _content(ListState s, ListViewModel vm) {
    final shop = s.mode == ListMode.buy;
    // The layout may have moved the cards (a mode switch, a new group): measure again.
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateDock());
    return Stack(
      key: _stackKey,
      children: [_column(s, vm, shop), _dockOverlay()],
    );
  }

  /// The top group (bar, banners) is laid out first and the list gets the rest, but the
  /// group is the last child, so it paints over the list: the shadows of its buttons
  /// fade out over the first rows instead of being cut at the bottom edge of the bar.
  Widget _column(ListState s, ListViewModel vm, bool shop) {
    final top = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (kDebugMode && ref.watch(userSlotProvider) != groupUserIds.first)
          Container(
            height: 20,
            width: double.infinity,
            color: context.tokens.tint,
            alignment: Alignment.center,
            child: Text(
              ref.watch(userNameProvider(s.userId)),
              style: Theme.of(context).textTheme.bodySmall!
                  .copyWith(color: context.tokens.muted),
            ),
          ),
        _header(s),
        // They grow and shrink instead of pushing the list in one frame.
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Column(
            children: [
              if (_showPresence(s, shop)) _presence(s),
              if (_noticeLines(s).isNotEmpty)
                NoticeBanner(
                  lines: _noticeLines(s),
                  onDismiss: vm.dismissNotices,
                ),
            ],
          ),
        ),
      ],
    );
    // The list fades into the page under the bar; the switcher has its own edge.
    final list = EdgeFade(
      bottom: false,
      child: ListView(
        controller: _scroll,
        // Bottom room so the Send button never covers the last row; while
        // searching, room to scroll the Frequent title to the top.
        padding: EdgeInsets.fromLTRB(
          context.tokens.gutter,
          context.tokens.listTopPadding,
          context.tokens.gutter,
          (shop && s.finding ? MediaQuery.sizeOf(context).height * 0.6 : 136) +
              MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          if (shop) ...[
            // Rows never move on a tap. What another member added since my last
            // visit stays in place and shows the author under the name.
            if (s.toBuy.isNotEmpty) ...[
              _card(
                key: const Key('toBuyCard'),
                title: CardTitle(
                  context.l10n.toBuy,
                  trailing: _markAllButton(s, s.toBuy, const Key('markAll')),
                ),
                body: _group(
                  s,
                  s.toBuy,
                  vm,
                  planned: true,
                  divider: true,
                  framed: false,
                ),
              ),
              const SizedBox(height: 16),
            ],
            KeyedSubtree(
              key: const Key('frequentCard'),
              child: _card(
                key: _frequentKey,
                title: s.finding
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: _field(s, vm),
                      )
                    : CardTitle(
                        context.l10n.frequent,
                        trailing: KeyedSubtree(
                          key: _findKey,
                          child: ValueListenableBuilder<bool>(
                            valueListenable: _overlayOn,
                            builder: (context, on, button) =>
                                Opacity(opacity: on ? 0 : 1, child: button),
                            child: CardIconAction(
                              key: const Key('findButton'),
                              onPressed: _openFind,
                              icon: Icons.search,
                              label: context.l10n.search,
                            ),
                          ),
                        ),
                      ),
                body: Column(
                  key: const Key('frequentRows'),
                  children: [
                    if (s.canAdd)
                      _addRow(s)
                    else if (s.toBuy.isEmpty &&
                        s.frequentShown.isEmpty &&
                        !s.finding)
                      _emptyRow(),
                    for (var i = 0; i < s.frequentShown.length; i++)
                      _row(
                        s,
                        s.frequentShown[i],
                        vm,
                        key: ValueKey(s.frequentShown[i].id),
                        divider: true,
                      ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Plan is one list: a needed product is marked in place. What another
            // member added since my last visit sits on top as one "New" group.
            if (s.newProducts.isNotEmpty) ...[
              _newGroup(s, vm),
              const SizedBox(height: 16),
            ],
            KeyedSubtree(
              key: const Key('selectCard'),
              child: _card(
                key: _selectKey,
                title: _planFind || s.searching
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: _field(s, vm),
                      )
                    : CardTitle(
                        context.l10n.select,
                        trailing: KeyedSubtree(
                          key: _findKey,
                          child: ValueListenableBuilder<bool>(
                            valueListenable: _overlayOn,
                            builder: (context, on, button) =>
                                Opacity(opacity: on ? 0 : 1, child: button),
                            child: CardIconAction(
                              key: const Key('findButton'),
                              onPressed: _openFind,
                              icon: Icons.search,
                              label: context.l10n.search,
                            ),
                          ),
                        ),
                      ),
                body: Column(
                  children: [
                    if (s.canAdd)
                      _addRow(s)
                    else if (s.plainProducts.isEmpty &&
                        !_planFind &&
                        !s.searching)
                      _emptyRow(),
                    _group(
                      s,
                      s.searching ? s.visible : s.plainProducts,
                      vm,
                      divider: true,
                      framed: false,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
    return CustomMultiChildLayout(
      delegate: _TopOverListLayout(),
      children: [
        LayoutId(id: _Slot.list, child: list),
        LayoutId(id: _Slot.top, child: top),
      ],
    );
  }

  /// A card with no rows: one button to the "Add products" screen, no explanation.
  Widget _emptyRow() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
    child: SizedBox(
      width: double.infinity,
      child: PlainButton(
        key: const Key('emptyAdd'),
        label: context.l10n.addProductsTitle,
        onPressed: _addProducts,
      ),
    ),
  );

  /// The first row of the card while the typed name matches nothing: adds it.
  Widget _addRow(ListState s) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
    child: SizedBox(
      width: double.infinity,
      child: PlainButton(
        key: const Key('addNew'),
        label: context.l10n.addQuery(s.query.trim()),
        onPressed: () => _add(s.query),
      ),
    ),
  );

  /// The one search field: it takes the place of the title of the Select card in Plan
  /// and of the Frequent card in Shop.
  Widget _field(ListState s, ListViewModel vm) {
    final shop = s.mode == ListMode.buy;
    return SoftField(
      child: TextField(
        key: const Key('addField'),
        controller: _search,
        focusNode: _searchFocus,
        autofocus: true,
        decoration: InputDecoration(
          hintText: shop ? context.l10n.find : context.l10n.search,
          suffixIcon: IconButton(
            tooltip: context.l10n.closeSearch,
            onPressed: () => _closeField(s),
            icon: const Icon(Icons.close),
          ),
        ),
        textInputAction: TextInputAction.done,
        onChanged: vm.setQuery,
        onSubmitted: (_) => _submit(),
      ),
    );
  }

  /// A Shop card: a centred title, then rows.
  Widget _card({Key? key, required Widget title, required Widget body}) =>
      _rounded(
        key: key,
        child: Column(children: [title, body]),
      );

  /// Cards and row groups share one rounded shape; an outline when the style asks for
  /// it.
  Widget _rounded({Key? key, required Widget child}) =>
      Panel(key: key, child: child);

  /// The text of the strip: who else is shopping now and how much they have taken.
  String _presenceText(ListState s) => [
    for (final e in s.othersTaken.entries)
      context.l10n.shoppingTaken(ref.watch(userNameProvider(e.key)), e.value),
  ].join(' · ');

  /// Whether the strip is shown: a tap hides it until its text changes (somebody takes
  /// another product) or until nobody is shopping any more.
  bool _showPresence(ListState s, bool shop) {
    if (!shop || s.othersTaken.isEmpty || !_namesReady) {
      if (s.othersTaken.isEmpty && _presenceHidden != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _presenceHidden = null);
        });
      }
      return false;
    }
    return _presenceText(s) != _presenceHidden;
  }

  Widget _presence(ListState s) {
    final text = _presenceText(s);
    // The same raised card as the notice banner, so both read as messages; a tap hides it.
    return Padding(
      key: const Key('presence'),
      padding: EdgeInsets.fromLTRB(
        context.tokens.gutter,
        4,
        context.tokens.gutter,
        12,
      ),
      child: Panel(
        child: InkWell(
          onTap: () => setState(() => _presenceHidden = text),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            // The accent dot of every notice, level with the middle of the first line.
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: AccentDot(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.close, size: 18, color: context.tokens.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The tint repeats the bottom tab, so the screen is never mistaken.
  Widget _header(ListState s) {
    final shop = s.mode == ListMode.buy;
    final menuLabel =
        ref.watch(updateViewModelProvider.select((u) => u.hasUpdate))
        ? context.l10n.menuUpdateAvailable
        : context.l10n.menu;
    final activeId = ref.watch(activeGroupIdProvider);
    final name =
        ref
            .watch(groupsViewModelProvider)
            .value
            ?.where((g) => g.id == activeId)
            .firstOrNull
            ?.name ??
        '';
    return ValueListenableBuilder<bool>(
      valueListenable: _hideStatus,
      builder: (context, hide, _) => KeyedSubtree(
        key: _barKey,
        child: TopBar(
          shop: shop,
          name: name,
          toBuyCount: shop ? 0 : s.toBuyCount,
          statusKey: _statusKey,
          hideStatus: hide,
          onGroup: _switchGroup,
          onGroupLongPress: kDebugMode ? () => _debugUser(s.userId) : null,
          onAdd: shop ? null : _addProducts,
          offline: ref.watch(offlineProvider),
          menu: _menu(s, menuLabel),
        ),
      ),
    );
  }

  Widget _menu(ListState s, String menuLabel) => context.tokens.depth > 0
      ? RaisedIcon(
          key: const Key('menuButton'),
          label: menuLabel,
          onPressed: () => _openMenu(s),
          child: _menuIcon(),
        )
      : IconButton(
          key: const Key('menuButton'),
          tooltip: menuLabel,
          onPressed: () => _openMenu(s),
          icon: _menuIcon(),
        );

  /// The "⋮" menu: a small floating card at the top right.
  Future<void> _openMenu(ListState s) async {
    final shop = s.mode == ListMode.buy;
    final picked = await showCardMenu<String>(
      context,
      items: [
        if (!shop) CardMenuItem('sort', context.l10n.sort),
        if (!shop && s.plans.isNotEmpty)
          CardMenuItem('plans', context.l10n.templates),
        if (!shop &&
            (ref.read(archivedProductsProvider).value?.isNotEmpty ?? false))
          CardMenuItem('archive', context.l10n.archive),
        CardMenuItem('history', context.l10n.history),
        CardMenuItem(
          'settings',
          context.l10n.settings,
          trailing: ref.read(updateViewModelProvider).hasUpdate
              ? const AccentDot(key: Key('settingsUpdateDot'))
              : null,
        ),
      ],
    );
    if (picked == null || !mounted) return;
    switch (picked) {
      case 'sort':
        await _sort();
      case 'plans':
        await showPlansSheet(context);
      case 'archive':
        await Navigator.of(
          context,
        ).push<void>(MaterialPageRoute(builder: (_) => const ArchiveScreen()));
      case 'history':
        await Navigator.of(
          context,
        ).push<void>(MaterialPageRoute(builder: (_) => const HistoryScreen()));
      default:
        await Navigator.of(
          context,
        ).push<void>(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    }
  }

  String _nameOf(String? userId) =>
      userId == null ? '' : ref.watch(userNameProvider(userId));

  /// Long press: the rename/delete card floats above the row (below it when the row is
  /// at the top of the screen) and the row shows its drag handle.
  void _openRowMenu(Product p, BuildContext rowContext) {
    Haptics.tick(context);
    _closeMenu();
    final box = rowContext.findRenderObject() as RenderBox;
    final top = box.localToGlobal(Offset.zero).dy;
    final above = top > MediaQuery.paddingOf(context).top + 96;
    setState(() => _menuId = p.id);
    _menuEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: 0,
        top: 0,
        child: CompositedTransformFollower(
          link: _menuLink,
          showWhenUnlinked: false,
          targetAnchor: above ? Alignment.topRight : Alignment.bottomRight,
          followerAnchor: above ? Alignment.bottomRight : Alignment.topRight,
          offset: Offset(-16, above ? -4 : 4),
          child: TapRegion(
            groupId: _menuGroup,
            onTapOutside: (_) => _closeMenu(),
            child: RowMenuCard(
              onRename: () => _renameProduct(p),
              onDelete: () => _deleteProduct(p),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_menuEntry!);
  }

  void _closeMenu() {
    _menuEntry?.remove();
    _menuEntry = null;
    if (_menuId != null && mounted) setState(() => _menuId = null);
  }

  Future<void> _renameProduct(Product p) async {
    _closeMenu();
    final l10n = context.l10n;
    final vm = ref.read(listViewModelProvider.notifier);
    await showCardDialog<void>(
      context,
      builder: (_) => PromptDialog(
        title: l10n.rename,
        hint: l10n.nameHint,
        confirm: l10n.save,
        initial: p.name,
        maxLength: maxProductNameLength,
        onSubmit: (text) async => switch (await vm.renameProduct(p, text)) {
          null => null,
          NameProblem.duplicate => l10n.nameTaken,
          NameProblem.empty => l10n.enterName,
        },
      ),
    );
  }

  Future<void> _deleteProduct(Product p) async {
    _closeMenu();
    final vm = ref.read(listViewModelProvider.notifier);
    await vm.deleteProduct(p);
    if (!mounted) return;
    showToast(
      context,
      context.l10n.productDeleted(p.name),
      actionLabel: context.l10n.undo,
      onAction: () => vm.undoDeleteProduct(p),
    );
  }

  /// "New · Anna": who added the products, once each, in the order of the rows.
  String _newLabel(ListState s) {
    final authors = {for (final p in s.newProducts) _nameOf(p.plannedBy)}
        .where((n) => n.isNotEmpty)
        .join(', ');
    return authors.isEmpty
        ? context.l10n.newLabel
        : context.l10n.newBy(authors);
  }

  /// "Mark all" of one card: takes that card's products nobody has taken yet; null
  /// when there are none.
  Widget? _markAllButton(ListState s, List<Product> card, Key key) =>
      s.untakenOf(card).isEmpty
      ? null
      : CardIconAction(
          key: key,
          onPressed: () => _markAll(card),
          icon: Icons.check,
          label: context.l10n.markAll,
        );

  /// Plan: the "New" group, one label, then plain rows that are tapped in place; no
  /// drag. Shop has no group: the rows show the author instead.
  Widget _newGroup(ListState s, ListViewModel vm) {
    final fresh = s.newProducts;
    return Column(
      key: const Key('newGroup'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _card(
          title: CardTitle(_newLabel(s)),
          body: Column(
            children: [
              for (var i = 0; i < fresh.length; i++)
                _row(
                  s,
                  fresh[i],
                  vm,
                  key: ValueKey(fresh[i].id),
                  divider: true,
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Long press starts a drag; reordering stays inside the list shown here. [planned]
  /// only tells the To buy card from the Plan list.
  Widget _group(
    ListState s,
    List<Product> products,
    ListViewModel vm, {
    bool? planned,
    bool divider = false,
    bool framed = true,
  }) {
    final list = ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: products.length,
      // The menu is anchored to the row: it must be gone before the row is lifted.
      onReorderStart: (_) => _closeMenu(),
      onReorderItem: (oldIndex, newIndex) =>
          vm.reorder(group: products, oldIndex: oldIndex, newIndex: newIndex),
      itemBuilder: (context, i) {
        final p = products[i];
        return _row(
          s,
          p,
          vm,
          key: ValueKey(p.id),
          // The drag starts from the handle that a long press shows.
          reorderIndex: s.canReorder ? i : null,
          divider: divider || i > 0,
          // The same product can be in a search result too; only one blinks.
          flash: !(s.finding && planned == true),
        );
      },
    );
    return framed ? _rounded(child: list) : list;
  }

  Widget _row(
    ListState s,
    Product p,
    ListViewModel vm, {
    Key? key,
    required bool divider,
    bool flash = true,
    int? reorderIndex,
  }) {
    final plan = s.mode == ListMode.need;
    final mark = s.markOf(p.id);
    // Shop has no "New" group: such a row names its author under the product.
    final addedBy = !plan && s.newProducts.any((n) => n.id == p.id)
        ? _nameOf(p.plannedBy)
        : '';
    return FlashOnAdd(
      key: key,
      flash: flash && s.flashId == p.id,
      onDone: ref.read(listViewModelProvider.notifier).clearFlash,
      // A tap on a row is not "outside" the menu: the row closes it itself.
      child: TapRegion(
        groupId: _menuGroup,
        child: Builder(
          builder: (rowContext) => ProductRow(
            name: p.name,
            mark: mark,
            needed: plan && p.planned,
            takenBy: _nameOf(s.partnerOf(p.id)),
            addedBy: addedBy,
            minHeight: plan ? 56 : 64,
            showDivider: divider,
            onLongPress: () => _openRowMenu(p, rowContext),
            menuLink: _menuId == p.id ? _menuLink : null,
            handle: _menuId == p.id && reorderIndex != null
                ? TapRegion(
                    groupId: _menuGroup,
                    child: ReorderableDragStartListener(
                      index: reorderIndex,
                      child: DragHandle(key: Key('dragHandle-${p.id}')),
                    ),
                  )
                : null,
            onTap: () {
              // A tap anywhere in the list only closes an open menu.
              if (_menuId != null) {
                _closeMenu();
                return;
              }
              if (mark == RowMark.partner) {
                _hintTaken(
                  context.l10n.alreadyBoughtBy(_nameOf(s.partnerOf(p.id))),
                );
                return;
              }
              // Plan never unmarks: a product that vanished from the trip would
              // raise "where did it go".
              if (plan && mark == RowMark.mine) {
                _hintTaken(context.l10n.youAlreadyBought);
                return;
              }
              if (s.mode == ListMode.buy) {
                Haptics.tick(context);
              }
              vm.tap(p);
            },
          ),
        ),
      ),
    );
  }
}

enum _Slot { top, list }

/// Top group first at its natural height, the list in the rest of the height below it.
class _TopOverListLayout extends MultiChildLayoutDelegate {
  _TopOverListLayout();

  @override
  void performLayout(Size size) {
    final top = layoutChild(
      _Slot.top,
      BoxConstraints.loose(Size(size.width, size.height))
          .tighten(width: size.width),
    );
    positionChild(_Slot.top, Offset.zero);
    layoutChild(
      _Slot.list,
      BoxConstraints.tight(
        Size(size.width, math.max(0, size.height - top.height)),
      ),
    );
    positionChild(_Slot.list, Offset(0, top.height));
  }

  @override
  bool shouldRelayout(_TopOverListLayout old) => false;
}
