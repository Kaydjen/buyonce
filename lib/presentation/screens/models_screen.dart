import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../domain/models/gemini_task.dart';
import '../../l10n/l10n.dart';
import '../view_models/settings/gemini_models_view_model.dart';
import '../widgets/edge_fade.dart';
import '../widgets/plain_button.dart';
import '../widgets/titled_card.dart';
import 'model_picker_screen.dart';

/// Settings > Gemini > Models: the models a photo is tried on, in order. The first one
/// answers; when it is limited or overloaded the next one takes over.
class ModelsScreen extends ConsumerWidget {
  const ModelsScreen({super.key, this.task = GeminiTask.items});

  final GeminiTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = geminiModelsProvider(task);
    final models = ref.watch(provider).value ?? task.defaultModels;
    final vm = ref.read(provider.notifier);
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.gemini)),
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ReorderableListView.builder(
                  key: const Key('modelList'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: models.length,
                  onReorderItem: vm.reorder,
                  itemBuilder: (context, i) => _ModelRow(
                    key: ValueKey(models[i]),
                    index: i,
                    id: models[i],
                    removable: models.length > 1,
                    onRemove: () => vm.remove(models[i]),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: PlainButton(
                        key: const Key('addModel'),
                        raised: true,
                        label: context.l10n.add,
                        onPressed: () => _add(context, vm, models),
                      ),
                    ),
                    if (!vm.isDefault) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: PlainButton(
                          key: const Key('resetModels'),
                          label: context.l10n.reset,
                          onPressed: vm.reset,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _add(
    BuildContext context,
    GeminiModelsViewModel vm,
    List<String> models,
  ) async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => ModelPickerScreen(chosen: models)),
    );
    if (id != null) await vm.add(id);
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({
    super.key,
    required this.index,
    required this.id,
    required this.removable,
    required this.onRemove,
  });

  final int index;
  final String id;
  final bool removable;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: SizedBox(
        width: 24,
        child: Text('${index + 1}', style: TextStyle(color: t.muted)),
      ),
      title: Text(id),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (removable)
            IconButton(
              key: Key('removeModel-$id'),
              icon: const Icon(Icons.close),
              color: t.muted,
              onPressed: onRemove,
            ),
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.drag_indicator, color: t.muted),
            ),
          ),
        ],
      ),
    );
  }
}
