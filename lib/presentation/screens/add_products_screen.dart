import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../view_models/drafts/drafts_view_model.dart';
import '../view_models/groups/groups_view_model.dart';
import '../view_models/list/list_view_model.dart';
import '../widgets/accent_button.dart';
import '../widgets/inset.dart';

/// Several products at once: Enter turns the typed name into a draft row and the
/// keyboard stays; "Add N" makes the drafts needed. Pops with how many products changed.
class AddProductsScreen extends ConsumerStatefulWidget {
  const AddProductsScreen({super.key});

  @override
  ConsumerState<AddProductsScreen> createState() => _AddProductsScreenState();
}

class _AddProductsScreenState extends ConsumerState<AddProductsScreen> {
  final _field = TextEditingController();
  final _focus = FocusNode();

  String get _groupId => ref.read(activeGroupIdProvider)!;

  DraftsViewModel get _drafts =>
      ref.read(draftsViewModelProvider(_groupId).notifier);

  @override
  void dispose() {
    _focus.dispose();
    _field.dispose();
    super.dispose();
  }

  void _submit() {
    _drafts.add(_field.text);
    _field.clear();
    // Done closes the keyboard by default; the next name is typed right away.
    _focus.requestFocus();
  }

  Future<void> _commit() async {
    // A name typed but not confirmed with Enter is not lost.
    _drafts.add(_field.text);
    _field.clear();
    final names = ref.read(draftsViewModelProvider(_groupId));
    if (names.isEmpty) return;
    final changed = await ref
        .read(listViewModelProvider.notifier)
        .addProducts(names);
    _drafts.clear();
    if (mounted) Navigator.of(context).pop(changed);
  }

  @override
  Widget build(BuildContext context) {
    final drafts = ref.watch(draftsViewModelProvider(_groupId));
    return Scaffold(
      appBar: AppBar(title: const Text('Add products')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.tokens.gutter,
              8,
              context.tokens.gutter,
              8,
            ),
            child: SoftField(
              child: TextField(
                key: const Key('draftField'),
                controller: _field,
                focusNode: _focus,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Name'),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                context.tokens.gutter,
                4,
                context.tokens.gutter,
                96,
              ),
              children: [
                for (final name in drafts)
                  _DraftRow(
                    key: ValueKey(name),
                    name: name,
                    onRemove: () => _drafts.remove(name),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _field,
        builder: (context, _) {
          final pending =
              _field.text.trim().isNotEmpty && !_drafts.has(_field.text);
          final count = drafts.length + (pending ? 1 : 0);
          return IgnorePointer(
            ignoring: count == 0,
            child: AnimatedOpacity(
              opacity: count == 0 ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: AccentButton(
                buttonKey: const Key('addCommit'),
                label: 'Add $count',
                onPressed: _commit,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One product to add. Only the name for now; quantity, photo and description come
/// here later.
class _DraftRow extends StatelessWidget {
  const _DraftRow({super.key, required this.name, required this.onRemove});
  final String name;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.tokens.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(name, style: Theme.of(context).textTheme.bodyLarge),
          ),
          IconButton(
            key: ValueKey('remove-$name'),
            tooltip: 'Remove $name',
            onPressed: onRemove,
            icon: Icon(Icons.close, color: context.tokens.muted),
          ),
        ],
      ),
    );
  }
}
