import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/group.dart';
import '../../domain/models/notice.dart';
import '../../domain/models/product.dart';
import '../../core/theme/app_tokens.dart';
import '../view_models/account/account_view_model.dart';
import '../view_models/groups/groups_view_model.dart';
import '../view_models/list/list_state.dart';
import '../view_models/list/list_view_model.dart';
import '../view_models/update/update_view_model.dart';
import '../view_models/users/user_names_view_model.dart';
import '../widgets/debug_user_sheet.dart';
import '../widgets/flash_on_add.dart';
import '../widgets/group_dialogs.dart';
import '../widgets/group_sheet.dart';
import '../widgets/haptics.dart';
import 'add_products_screen.dart';
import 'group_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import '../widgets/notice_banner.dart';
import '../widgets/section_label.dart';
import '../widgets/product_row.dart';
import '../widgets/plans_sheet.dart';
import '../widgets/sign_in_prompt.dart';
import '../widgets/sort_sheet.dart';

class ListScreen extends ConsumerStatefulWidget {
  const ListScreen({super.key});

  @override
  ConsumerState<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends ConsumerState<ListScreen>
    with WidgetsBindingObserver {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _scroll = ScrollController();
  final _frequentKey = GlobalKey();
  double _lastKeyboardInset = 0;
  DateTime? _pausedAt;

  /// Away from the app this long counts as a new visit: Frequent is ranked again and
  /// the "New" group is counted from the start of the visit.
  static const _newVisit = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
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
    _searchFocus.dispose();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _search.clear();
    ref.read(listViewModelProvider.notifier).setQuery('');
  }

  /// The close icon of the field: Plan only clears it, Shop also hides it.
  void _closeField(ListState s) {
    _search.clear();
    final vm = ref.read(listViewModelProvider.notifier);
    s.mode == ListMode.buy ? vm.setFinding(false) : vm.setQuery('');
  }

  /// The search icon of the Frequent card: the field replaces the title and the card
  /// scrolls to the top, so the keyboard never covers the results.
  void _openFind() {
    ref.read(listViewModelProvider.notifier).setFinding(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final card = _frequentKey.currentContext;
      if (card == null) return;
      Scrollable.ensureVisible(
        card,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _setMode(ListMode mode) {
    _search.clear();
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Added: $changed')));
  }

  /// Takes everything still open; the snackbar can take it back.
  Future<void> _markAll(List<Product> card) async {
    final vm = ref.read(listViewModelProvider.notifier);
    final ids = await vm.markAll(card);
    if (!mounted || ids.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Marked: ${ids.length}'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => vm.undoMarkAll(ids),
          ),
        ),
      );
  }

  Future<void> _notify() async {
    Haptics.send(context);
    final count = await ref.read(listViewModelProvider.notifier).notify();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Notified: $count')));
  }

  Future<void> _ask() async {
    Haptics.send(context);
    final count = await ref.read(listViewModelProvider.notifier).ask();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Notified: $count')));
  }

  /// A tap on a product that is already taken: a short note at the bottom, it goes
  /// away by itself and replaces an earlier one instead of piling up.
  void _hintTaken(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
      );
  }

  /// Debug builds only: long press on the group name switches the user.
  Future<void> _debugUser(String current) async {
    final id = await showDebugUserSheet(context, current);
    if (id == null || !mounted) return;
    await ref.read(listViewModelProvider.notifier).selectUser(id);
  }

  List<String> _noticeLines(ListState s) => [
    for (final n in s.notices)
      '${ref.watch(userNameProvider(n.fromUserId))} ${n.kind == NoticeKind.needed ? 'needs' : 'bought'}: ${[for (final id in n.productIds) s.products.where((p) => p.id == id).map((p) => p.name).firstOrNull ?? '?'].join(', ')}',
  ];

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
    return Scaffold(
      body: SafeArea(
        child: switch (async) {
          AsyncData(:final value) => _content(value, vm),
          AsyncError() => const Center(child: Text('Failed to load')),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
      floatingActionButton: async.hasValue
          ? _sendButton(async.requireValue)
          : null,
      bottomNavigationBar: async.hasValue
          ? _ModeBar(mode: async.requireValue.mode, onSelect: _setMode)
          : null,
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
      _SendButton(
        visible: s.mode == ListMode.buy && s.hasUnsent,
        count: s.myMarkIds.length,
        autoSendAt: s.autoSendAt,
        onSend: _notify,
        label: _isPersonal ? 'Done' : 'Send',
      ),
      _SendButton(
        buttonKey: const Key('askButton'),
        visible:
            s.mode == ListMode.need && s.askProducts.isNotEmpty && _hasPartners,
        count: s.askProducts.length,
        autoSendAt: null,
        onSend: _ask,
        label: 'Notify',
      ),
    ],
  );

  Widget _content(ListState s, ListViewModel vm) {
    final shop = s.mode == ListMode.buy;
    return Column(
      children: [
        if (kDebugMode && s.userId != groupUserIds.first)
          Container(
            height: 20,
            width: double.infinity,
            color: context.tokens.tint,
            alignment: Alignment.center,
            child: Text(
              ref.watch(userNameProvider(s.userId)),
              style: TextStyle(fontSize: 12, color: context.tokens.muted),
            ),
          ),
        _header(s),
        if (shop && s.othersTaken.isNotEmpty) _presence(s),
        if (!shop)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _field(s, vm),
          ),
        if (s.notices.isNotEmpty)
          NoticeBanner(lines: _noticeLines(s), onDismiss: vm.dismissNotices),
        Expanded(
          child: ListView(
            controller: _scroll,
            // Bottom room so the Send button never covers the last row; while
            // searching, room to scroll the Frequent title to the top.
            padding: EdgeInsets.fromLTRB(
              16,
              4,
              16,
              shop && s.finding ? MediaQuery.sizeOf(context).height * 0.6 : 136,
            ),
            children: [
              if (shop) ...[
                // Rows never move on a tap. What another member added since my last
                // visit stays in place and shows the author under the name.
                if (s.toBuy.isNotEmpty) ...[
                  _card(
                    key: const Key('toBuyCard'),
                    title: _cardTitle(
                      'To buy',
                      trailing: _markAllButton(
                        s,
                        s.toBuy,
                        const Key('markAll'),
                      ),
                    ),
                    body: _group(s, s.toBuy, vm, planned: true, divider: true),
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
                        : _cardTitle(
                            'Frequent',
                            trailing: IconButton(
                              key: const Key('findButton'),
                              onPressed: _openFind,
                              icon: const Icon(Icons.search),
                            ),
                          ),
                    body: Column(
                      key: const Key('frequentRows'),
                      children: [
                        for (final p in s.frequentShown)
                          _row(s, p, vm, key: ValueKey(p.id), divider: true),
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
                if (s.searching
                    ? s.visible.isNotEmpty
                    : s.plainProducts.isNotEmpty)
                  _group(s, s.searching ? s.visible : s.plainProducts, vm),
              ],
              if (s.canAdd)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton(
                    onPressed: () => _add(s.query),
                    child: Text('+ Add "${s.query.trim()}"'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// The one search field: Plan keeps it above the list, Shop inside the Frequent card.
  Widget _field(ListState s, ListViewModel vm) {
    final shop = s.mode == ListMode.buy;
    return TextField(
      key: const Key('addField'),
      controller: _search,
      focusNode: _searchFocus,
      autofocus: shop,
      decoration: InputDecoration(
        hintText: shop ? 'Find' : 'Search',
        suffixIcon: s.query.isEmpty && !shop
            ? null
            : IconButton(
                onPressed: () => _closeField(s),
                icon: const Icon(Icons.close),
              ),
      ),
      textInputAction: TextInputAction.done,
      onChanged: vm.setQuery,
      onSubmitted: (_) => _submit(),
    );
  }

  /// A Shop card: a centred title, then rows.
  Widget _card({Key? key, required Widget title, required Widget body}) =>
      ClipRRect(
        key: key,
        borderRadius: BorderRadius.circular(14),
        child: Material(
          color: context.tokens.surface,
          child: Column(children: [title, body]),
        ),
      );

  Widget _cardTitle(String text, {Widget? trailing}) => SizedBox(
    height: 56,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Padding(
          // Room for a button on the right; the title stays centred.
          padding: EdgeInsets.symmetric(
            horizontal: trailing == null ? 16 : 112,
          ),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium!
                .copyWith(color: context.tokens.muted),
          ),
        ),
        if (trailing != null)
          Align(alignment: Alignment.centerRight, child: trailing),
      ],
    ),
  );

  /// Who else is shopping now and how much they have taken.
  Widget _presence(ListState s) {
    final text = [
      for (final e in s.othersTaken.entries)
        '${ref.watch(userNameProvider(e.key))} shopping, ${e.value} taken',
    ].join(' · ');
    return Container(
      key: const Key('presence'),
      width: double.infinity,
      color: context.tokens.tint,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium!
            .copyWith(color: context.tokens.muted),
      ),
    );
  }

  /// The tint repeats the bottom tab, so the screen is never mistaken.
  Widget _header(ListState s) {
    final shop = s.mode == ListMode.buy;
    return Container(
      color: shop ? context.tokens.tint : context.tokens.background,
      padding: const EdgeInsets.only(left: 8, right: 4),
      height: 56,
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('groupButton'),
                onPressed: _switchGroup,
                onLongPress: kDebugMode ? () => _debugUser(s.userId) : null,
                style: TextButton.styleFrom(
                  foregroundColor: context.tokens.muted,
                ),
                child: Text(
                  ref
                          .watch(groupsViewModelProvider)
                          .value
                          ?.where(
                            (g) => g.id == ref.watch(activeGroupIdProvider),
                          )
                          .firstOrNull
                          ?.name ??
                      '',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          ),
          if (!shop && s.toBuyCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '${s.toBuyCount} to buy',
                key: const Key('toBuyCount'),
                style: Theme.of(context).textTheme.bodyMedium!
                    .copyWith(color: context.tokens.muted),
              ),
            ),
          if (!shop)
            TextButton(
              key: const Key('addProducts'),
              onPressed: _addProducts,
              style: TextButton.styleFrom(
                foregroundColor: context.tokens.muted,
              ),
              child: const Text('Add'),
            ),
          PopupMenuButton<String>(
            key: const Key('menuButton'),
            icon: _menuIcon(),
            onSelected: (v) => switch (v) {
              'sort' => _sort(),
              'plans' => showPlansSheet(context),
              'history' => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              ),
              _ => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            },
            itemBuilder: (_) => [
              if (!shop)
                const PopupMenuItem(value: 'sort', child: Text('Sort')),
              if (!shop && s.plans.isNotEmpty)
                const PopupMenuItem(value: 'plans', child: Text('Templates')),
              const PopupMenuItem(value: 'history', child: Text('History')),
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    const Text('Settings'),
                    if (ref.read(updateViewModelProvider).hasUpdate) ...[
                      const SizedBox(width: 8),
                      Container(
                        key: const Key('settingsUpdateDot'),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: context.tokens.text,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _nameOf(String? userId) =>
      userId == null ? '' : ref.watch(userNameProvider(userId));

  /// "New · Anna": who added the products, once each, in the order of the rows.
  String _newLabel(ListState s) {
    final authors = {for (final p in s.newProducts) _nameOf(p.plannedBy)}
        .where((n) => n.isNotEmpty)
        .join(', ');
    return authors.isEmpty ? 'New' : 'New · $authors';
  }

  /// "Mark all" of one card: takes that card's products nobody has taken yet; null
  /// when there are none.
  Widget? _markAllButton(ListState s, List<Product> card, Key key) =>
      s.untakenOf(card).isEmpty
      ? null
      : TextButton(
          key: key,
          onPressed: () => _markAll(card),
          child: const Text('Mark all'),
        );

  /// Plan: the "New" group, one label, then plain rows that are tapped in place; no
  /// drag. Shop has no group: the rows show the author instead.
  Widget _newGroup(ListState s, ListViewModel vm) {
    final fresh = s.newProducts;
    return Column(
      key: const Key('newGroup'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(_newLabel(s), color: context.tokens.accent),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            children: [
              for (var i = 0; i < fresh.length; i++)
                _row(
                  s,
                  fresh[i],
                  vm,
                  key: ValueKey(fresh[i].id),
                  divider: i > 0,
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
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: products.length,
        onReorderItem: (oldIndex, newIndex) =>
            vm.reorder(group: products, oldIndex: oldIndex, newIndex: newIndex),
        itemBuilder: (context, i) {
          final p = products[i];
          return ReorderableDelayedDragStartListener(
            key: ValueKey(p.id),
            index: i,
            enabled: s.canReorder,
            child: _row(
              s,
              p,
              vm,
              divider: divider || i > 0,
              // The same product can be in a search result too; only one blinks.
              flash: !(s.finding && planned == true),
            ),
          );
        },
      ),
    );
  }

  Widget _row(
    ListState s,
    Product p,
    ListViewModel vm, {
    Key? key,
    required bool divider,
    bool flash = true,
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
      child: ProductRow(
        name: p.name,
        mark: mark,
        needed: plan && p.planned,
        takenBy: _nameOf(s.partnerOf(p.id)),
        addedBy: addedBy,
        minHeight: plan ? 56 : 64,
        showDivider: divider,
        onTap: () {
          if (mark == RowMark.partner) {
            _hintTaken('${_nameOf(s.partnerOf(p.id))} already bought this');
            return;
          }
          // Plan never unmarks: a product that vanished from the trip would
          // raise "where did it go".
          if (plan && mark == RowMark.mine) {
            _hintTaken('You already bought this');
            return;
          }
          if (s.mode == ListMode.buy) {
            Haptics.tick(context);
          }
          vm.tap(p);
        },
      ),
    );
  }
}

/// Floating Send button with the count: the only accent of the screen. It slides in
/// with my first unsent mark; above it the auto-send time.
class _SendButton extends StatelessWidget {
  const _SendButton({
    this.buttonKey = const Key('sendButton'),
    required this.visible,
    required this.count,
    required this.autoSendAt,
    required this.onSend,
    required this.label,
  });
  final Key buttonKey;
  final bool visible;
  final int count;
  final DateTime? autoSendAt;
  final VoidCallback onSend;

  /// "Send" in a group; "Done" in the personal list, where nobody is notified.
  final String label;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 2),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (autoSendAt != null) _AutoChip(at: autoSendAt!),
              const SizedBox(height: 8),
              FilledButton(
                key: buttonKey,
                style: FilledButton.styleFrom(
                  backgroundColor: context.tokens.accent,
                  foregroundColor: context.tokens.onAccent,
                  minimumSize: const Size(0, 56),
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                ),
                onPressed: onSend,
                child: Text(
                  '$label $count',
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.w500,
                    color: context.tokens.onAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Auto · 15:20", and "Auto · in 8 min" for the last ten minutes. It repeats the
/// idle rule, so the user knows the list goes out by itself.
class _AutoChip extends StatefulWidget {
  const _AutoChip({required this.at});
  final DateTime at;

  @override
  State<_AutoChip> createState() => _AutoChipState();
}

class _AutoChipState extends State<_AutoChip> {
  late final Timer _tick;
  String _shown = '';

  @override
  void initState() {
    super.initState();
    _shown = _text;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final text = _text;
      if (text != _shown) setState(() => _shown = text);
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  String get _text {
    final left = widget.at.difference(DateTime.now());
    if (left < const Duration(minutes: 1)) {
      return 'Auto · in ${left.inSeconds.clamp(1, 59)} s';
    }
    if (left <= const Duration(minutes: 10)) {
      final minutes = (left.inSeconds / 60).ceil().clamp(1, 10);
      return 'Auto · in $minutes min';
    }
    final t = widget.at.toLocal();
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return 'Auto · $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('autoChip'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.tokens.tint,
        borderRadius: BorderRadius.circular(context.tokens.radiusChip),
      ),
      child: Text(
        _shown,
        style: Theme.of(context).textTheme.bodySmall!
            .copyWith(color: context.tokens.muted),
      ),
    );
  }
}

/// Bottom two-tab switcher: text only, the selected tab is bold with a bar on top.
class _ModeBar extends StatelessWidget {
  const _ModeBar({required this.mode, required this.onSelect});
  final ListMode mode;
  final ValueChanged<ListMode> onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.tokens.surface,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _tab(context, ListMode.need, 'Plan', const Key('tabPlan')),
            _tab(context, ListMode.buy, 'Shop', const Key('tabShop')),
          ],
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, ListMode m, String label, Key key) {
    final selected = mode == m;
    return Expanded(
      child: InkWell(
        key: key,
        onTap: () => onSelect(m),
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                width: 3,
                color: selected ? context.tokens.text : const Color(0x00000000),
              ),
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              color: selected ? context.tokens.text : context.tokens.muted,
            ),
          ),
        ),
      ),
    );
  }
}
