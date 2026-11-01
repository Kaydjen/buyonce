import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../domain/models/plan.dart';
import '../view_models/list/list_view_model.dart';
import 'section_label.dart';

Future<void> showPlansSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const PlansSheet(),
  );
}

/// Quick add: pinned plans (templates) first, then recent plans. A plan is deleted by
/// a swipe or by its Delete icon; the strip at the bottom takes it back.
class PlansSheet extends ConsumerStatefulWidget {
  const PlansSheet({super.key});

  @override
  ConsumerState<PlansSheet> createState() => _PlansSheetState();
}

class _PlansSheetState extends ConsumerState<PlansSheet> {
  /// Plans deleted in this sheet: hidden at once, the last one can be restored.
  final _hidden = <String>{};
  Plan? _undo;

  void _delete(Plan plan) {
    setState(() {
      _hidden.add(plan.id);
      _undo = plan;
    });
    ref.read(listViewModelProvider.notifier).deletePlan(plan);
  }

  void _restore() {
    final plan = _undo;
    if (plan == null) return;
    setState(() {
      _hidden.remove(plan.id);
      _undo = null;
    });
    ref.read(listViewModelProvider.notifier).restorePlan(plan);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(listViewModelProvider).requireValue;
    final vm = ref.read(listViewModelProvider.notifier);
    final names = {for (final p in s.products) p.id: p.name};
    final plans = s.plans.where((p) => !_hidden.contains(p.id)).toList();
    final pinned = plans.where((p) => p.pinned).toList();
    final recent = plans.where((p) => !p.pinned).take(10).toList();

    Widget row(Plan plan) {
      final text = [
        for (final id in plan.productIds)
          if (names[id] != null) names[id]!,
      ].join(', ');
      return Dismissible(
        key: ValueKey(plan.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => _delete(plan),
        background: Container(
          color: context.tokens.tint,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: const Text('Delete'),
        ),
        child: InkWell(
          onTap: () async {
            // The marks land all over the catalog, so the count tells what happened.
            final messenger = ScaffoldMessenger.of(context);
            Navigator.of(context).pop();
            final added = await vm.applyPlan(plan);
            if (added == 0) return;
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text('Added: $added')));
          },
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => vm.togglePinned(plan),
                  icon: Icon(
                    plan.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                    color: plan.pinned
                        ? context.tokens.text
                        : context.tokens.muted,
                  ),
                ),
                IconButton(
                  key: Key('delete-${plan.id}'),
                  onPressed: () => _delete(plan),
                  icon: Icon(Icons.delete_outline, color: context.tokens.muted),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 0, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pinned.isNotEmpty) ...[
              const SectionLabel('Templates'),
              for (final plan in pinned) row(plan),
            ],
            if (recent.isNotEmpty) ...[
              const SectionLabel('Recent'),
              for (final plan in recent) row(plan),
            ],
            if (_undo != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Deleted',
                        style: Theme.of(context).textTheme.bodyMedium!
                            .copyWith(color: context.tokens.muted),
                      ),
                    ),
                    TextButton(
                      key: const Key('undoDelete'),
                      onPressed: _restore,
                      child: const Text('Undo'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
