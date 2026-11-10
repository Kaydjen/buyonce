import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../l10n/l10n.dart';
import '../../domain/models/gemini_outcome.dart';
import '../view_models/drafts/drafts_view_model.dart';
import '../view_models/drafts/name_suggestion_view_model.dart';
import '../view_models/settings/gemini_key_view_model.dart';
import '../view_models/groups/groups_view_model.dart';
import '../view_models/list/list_view_model.dart';
import '../widgets/accent_button.dart';
import '../widgets/api_key_dialog.dart';
import '../widgets/inset.dart';
import '../widgets/toast.dart';
import 'models_screen.dart';

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
  void initState() {
    super.initState();
    // A photo taken before Android killed the app while the camera was open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(nameSuggestionProvider.notifier).recoverLost(_language);
      }
    });
  }

  /// The English name of the app language, for a model that finds no name on the photo.
  String get _language => Localizations.localeOf(context).languageCode == 'uk'
      ? 'Ukrainian'
      : 'English';

  NameSuggestionViewModel get _names =>
      ref.read(nameSuggestionProvider.notifier);

  /// No key yet: the key dialog first, then the camera.
  Future<void> _camera() async {
    if (await ref.read(geminiKeyProvider.future) == null) {
      if (!mounted) return;
      await showApiKeyDialog(context, ref);
      if (!mounted || await ref.read(geminiKeyProvider.future) == null) return;
    }
    await _names.takePhoto(_language);
  }

  /// A suggested name goes into the field, ready to be edited or added.
  void _pick(String name) {
    _field.value = TextEditingValue(
      text: name,
      selection: TextSelection.collapsed(offset: name.length),
    );
    _focus.requestFocus();
  }

  void _showProblem(GeminiOutcome problem) {
    _names.problemShown();
    final l10n = context.l10n;
    void openModels() => Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const ModelsScreen()));
    Future<void> keyThenRetry() async {
      await showApiKeyDialog(context, ref);
      if (mounted && await ref.read(geminiKeyProvider.future) != null) {
        await _names.retry(_language);
      }
    }

    switch (problem) {
      case GeminiLimited(:final model):
        showToast(
          context,
          l10n.modelLimitReached(model),
          actionLabel: l10n.addModels,
          onAction: openModels,
        );
      case GeminiAllLimited():
        showToast(
          context,
          l10n.allModelsLimited,
          actionLabel: l10n.addModels,
          onAction: openModels,
        );
      case GeminiOffline():
        showToast(
          context,
          l10n.noConnection,
          actionLabel: l10n.retry,
          onAction: () => _names.retry(_language),
        );
      case GeminiBadKey():
        showToast(
          context,
          l10n.apiKeyRejected,
          actionLabel: l10n.apiKey,
          onAction: keyThenRetry,
        );
      case GeminiNoKey():
        keyThenRetry();
      case GeminiFailed() || GeminiOk():
        showToast(
          context,
          l10n.couldntNameItem,
          actionLabel: l10n.retry,
          onAction: () => _names.retry(_language),
        );
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _field.dispose();
    super.dispose();
  }

  void _submit() {
    _drafts.add(_field.text);
    _field.clear();
    _names.clearNames();
    // Done closes the keyboard by default; the next name is typed right away.
    _focus.requestFocus();
  }

  bool _committing = false;

  Future<void> _commit() async {
    if (_committing) return;
    // A name typed but not confirmed with Enter is not lost.
    _drafts.add(_field.text);
    _field.clear();
    _names.clearNames();
    final names = ref.read(draftsViewModelProvider(_groupId));
    if (names.isEmpty) return;
    _committing = true;
    final changed = await ref
        .read(listViewModelProvider.notifier)
        .addProducts(names);
    _drafts.clear();
    if (mounted) Navigator.of(context).pop(changed);
  }

  @override
  Widget build(BuildContext context) {
    final drafts = ref.watch(draftsViewModelProvider(_groupId));
    final suggestion = ref.watch(nameSuggestionProvider);
    ref.listen(nameSuggestionProvider.select((s) => s.problem), (_, problem) {
      if (problem != null) _showProblem(problem);
    });
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.addProductsTitle)),
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
                decoration: InputDecoration(
                  hintText: context.l10n.nameHint,
                  // The field stays usable while a photo is being read.
                  suffixIcon: suggestion.busy
                      ? const _Waiting(key: Key('photoBusy'))
                      : IconButton(
                          key: const Key('photoButton'),
                          tooltip: context.l10n.photoTooltip,
                          icon: const Icon(Icons.photo_camera_outlined),
                          onPressed: _camera,
                        ),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
            ),
          ),
          if (suggestion.names.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.tokens.gutter,
                0,
                context.tokens.gutter,
                8,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final name in suggestion.names)
                      _NameChip(name: name, onTap: () => _pick(name)),
                  ],
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
                label: context.l10n.addCount(count),
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
            tooltip: context.l10n.removeProductTooltip(name),
            onPressed: onRemove,
            icon: Icon(Icons.close, color: context.tokens.muted),
          ),
        ],
      ),
    );
  }
}

/// The spinner that takes the place of the camera icon while a photo is read.
class _Waiting extends StatelessWidget {
  const _Waiting({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(14),
    child: SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
  );
}

/// A name the photo suggested: a tint plate, a tap puts it into the field.
class _NameChip extends StatelessWidget {
  const _NameChip({required this.name, required this.onTap});
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.tint,
      borderRadius: BorderRadius.circular(t.radiusButton),
      child: InkWell(
        key: ValueKey('chip-$name'),
        borderRadius: BorderRadius.circular(t.radiusButton),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(name),
          ),
        ),
      ),
    );
  }
}
