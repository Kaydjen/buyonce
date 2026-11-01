import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/group.dart';
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
import 'group_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import '../widgets/notice_banner.dart';
import '../widgets/product_row.dart';
import '../widgets/plans_sheet.dart';
import '../widgets/section_label.dart';
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
  double _lastKeyboardInset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

  /// Takes everything still open; the snackbar can take it back.
  Future<void> _markAll() async {
    final vm = ref.read(listViewModelProvider.notifier);
    final ids = await vm.markAll();
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

  /// A tap on a product another member already took: a short note at the bottom, it
  /// goes away by itself and replaces an earlier one instead of piling up.
  void _hintTakenBy(String name) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$name already bought this'),
          duration: const Duration(seconds: 2),
        ),
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
      '${ref.watch(userNameProvider(n.fromUserId))} bought: ${[for (final id in n.productIds) s.products.where((p) => p.id == id).map((p) => p.name).firstOrNull ?? '?'].join(', ')}',
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

  /// A floating action button, so a snackbar pushes it up instead of covering it.
  Widget _sendButton(ListState s) => _SendButton(
    visible: s.mode == ListMode.buy && s.hasUnsent,
    count: s.myMarkIds.length,
    autoSendAt: s.autoSendAt,
    onSend: _notify,
    label: _isPersonal ? 'Done' : 'Send',
  );

  Widget _content(ListState s, ListViewModel vm) {
    final planned = s.plannedVisible;
    final rest = s.restVisible;
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
        if (!shop || s.finding)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              key: const Key('addField'),
              controller: _search,
              focusNode: _searchFocus,
              autofocus: shop,
              decoration: InputDecoration(
                hintText: shop ? 'Find' : 'Add product',
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
            ),
          ),
        if (s.notices.isNotEmpty)
          NoticeBanner(lines: _noticeLines(s), onDismiss: vm.dismissNotices),
        Expanded(
          child: ListView(
            controller: _scroll,
            // Bottom room so the notify button never covers the last row.
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 136),
            children: [
              // Search results are one flat list, so a tap changes a row in place
              // instead of moving it into another group.
              if (s.flatList) ...[
                if (s.visible.isNotEmpty)
                  _group(s, s.visible, vm, isPlanned: false),
              ] else ...[
                if (planned.isNotEmpty) ...[
                  if (!shop) const SectionLabel('List'),
                  _group(s, planned, vm, isPlanned: true),
                  const SizedBox(height: 16),
                ],
                if (rest.isNotEmpty) _group(s, rest, vm, isPlanned: false),
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
          if (shop && !s.finding && s.untaken.isNotEmpty)
            TextButton(
              key: const Key('markAll'),
              onPressed: _markAll,
              child: const Text('Mark all'),
            ),
          if (shop && !s.finding)
            IconButton(
              onPressed: () =>
                  ref.read(listViewModelProvider.notifier).setFinding(true),
              icon: const Icon(Icons.search),
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

  /// Long press starts a drag; reordering stays inside the group.
  Widget _group(
    ListState s,
    List<Product> products,
    ListViewModel vm, {
    required bool isPlanned,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: products.length,
        onReorderItem: (oldIndex, newIndex) => vm.reorder(
          planned: isPlanned,
          oldIndex: oldIndex,
          newIndex: newIndex,
        ),
        itemBuilder: (context, i) {
          final p = products[i];
          final mark = s.markOf(p.id);
          return ReorderableDelayedDragStartListener(
            key: ValueKey(p.id),
            index: i,
            enabled: s.canReorder,
            child: FlashOnAdd(
              flash: s.flashId == p.id,
              child: ProductRow(
                name: p.name,
                mark: mark,
                planned: s.searching && s.mode == ListMode.need && p.planned,
                takenBy: _nameOf(s.partnerOf(p.id)),
                minHeight: s.mode == ListMode.buy ? 64 : 56,
                showDivider: i > 0,
                onTap: () {
                  if (mark == RowMark.partner) {
                    _hintTakenBy(_nameOf(s.partnerOf(p.id)));
                    return;
                  }
                  if (s.mode == ListMode.buy) {
                    Haptics.tick(context);
                  }
                  vm.tap(p);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Floating Send button with the count: the only accent of the screen. It slides in
/// with my first unsent mark; above it the auto-send time.
class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.visible,
    required this.count,
    required this.autoSendAt,
    required this.onSend,
    required this.label,
  });
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
                key: const Key('sendButton'),
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
