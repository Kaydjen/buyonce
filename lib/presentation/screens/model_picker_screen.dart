import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/result.dart';
import '../../data/repositories/gemini_models_repository.dart';
import '../../domain/models/gemini_task.dart';
import '../../l10n/l10n.dart';
import '../view_models/settings/gemini_models_view_model.dart';
import '../widgets/card_dialog.dart';
import '../widgets/edge_fade.dart';
import '../widgets/group_dialogs.dart';
import '../widgets/plain_button.dart';
import '../widgets/titled_card.dart';

/// Pops with the id of the model the user picked: one of the models the key can use, or
/// an id typed by hand ("Other").
class ModelPickerScreen extends ConsumerWidget {
  const ModelPickerScreen({super.key, required this.chosen});

  /// Ids already in the list: shown ticked, not offered again.
  final List<String> chosen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(availableModelsProvider);
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.add)),
      body: EdgeFade(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            t.gutter,
            t.listTopPadding,
            t.gutter,
            24,
          ),
          child: TitledCard(
            title: context.l10n.models,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  key: const Key('otherModel'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.otherModel),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _typeId(context),
                ),
                ..._body(context, ref, available),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _body(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Result<List<GeminiModelInfo>>> available,
  ) {
    if (available.isLoading) {
      return const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    final error = available.listError;
    if (error != null) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(_errorText(context, error), textAlign: TextAlign.center),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: PlainButton(
            key: const Key('retryModels'),
            label: context.l10n.retry,
            onPressed: () => ref.invalidate(availableModelsProvider),
          ),
        ),
      ];
    }
    final models = (available.value! as Ok<List<GeminiModelInfo>>).value;
    return [
      for (final m in models)
        ListTile(
          key: Key('pick-${m.id}'),
          contentPadding: EdgeInsets.zero,
          title: Text(m.displayName),
          subtitle: Text(m.id, style: TextStyle(color: context.tokens.muted)),
          trailing: chosen.contains(m.id) ? const Icon(Icons.check) : null,
          enabled: !chosen.contains(m.id),
          onTap: () => Navigator.of(context).pop(m.id),
        ),
    ];
  }

  String _errorText(BuildContext context, ModelListError error) =>
      switch (error) {
        ModelListError.noKey => context.l10n.addApiKeyFirst,
        ModelListError.badKey => context.l10n.apiKeyRejected,
        ModelListError.offline => context.l10n.noConnection,
        ModelListError.failed => context.l10n.somethingWrong,
      };

  Future<void> _typeId(BuildContext context) async {
    final l10n = context.l10n;
    final navigator = Navigator.of(context);
    String? typed;
    await showCardDialog<void>(
      context,
      builder: (_) => PromptDialog(
        title: l10n.modelId,
        hint: l10n.modelId,
        confirm: l10n.add,
        plain: true,
        onSubmit: (text) async {
          final id = text.trim().replaceFirst('models/', '');
          if (id.contains(RegExp(r'\s'))) return l10n.invalidModelId;
          if (chosen.contains(id)) return l10n.modelAlreadyAdded;
          typed = id;
          return null;
        },
      ),
    );
    // The dialog closed on success; the picker follows with the id.
    if (typed != null) navigator.pop(typed);
  }
}
