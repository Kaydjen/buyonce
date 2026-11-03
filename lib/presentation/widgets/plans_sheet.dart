import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../domain/models/plan.dart';
import '../../l10n/l10n.dart';
import '../view_models/list/list_view_model.dart';
import 'card_sheet.dart';
import 'groove.dart';
import 'panel.dart';
import 'titled_card.dart';
import 'toast.dart';

Future<void> showPlansSheet(BuildContext context) {
  return showCardSheet<void>(
    context,
    fromTop: true,
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
          child: Text(context.l10n.delete),
        ),
        child: InkWell(
          onTap: () async {
            // The marks land all over the catalog, so the count tells what happened.
            final page = Navigator.of(context).context;
            Navigator.of(context).pop();
            final added = await vm.applyPlan(plan);
            if (added == 0 || !page.mounted) return;
            showToast(page, context.l10n.addedCount(added));
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
                  tooltip: plan.pinned ? context.l10n.unpin : context.l10n.pin,
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
                  tooltip: context.l10n.delete,
                  onPressed: () => _delete(plan),
                  icon: Icon(Icons.delete_outline, color: context.tokens.muted),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget plansCard(String title, List<Plan> list) => TitledCard(
      title: title,
      child: Column(
        children: [
          for (var i = 0; i < list.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Groove(tight: true),
              ),
            row(list[i]),
          ],
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (pinned.isNotEmpty) ...[
          plansCard(context.l10n.templates, pinned),
          const SizedBox(height: 16),
        ],
        if (recent.isNotEmpty) ...[
          plansCard(context.l10n.recent, recent),
          const SizedBox(height: 16),
        ],
        if (_undo != null)
          Panel(
            tinted: true,
            padding: const EdgeInsets.only(left: 16, right: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.deleted,
                    style: Theme.of(context).textTheme.bodyMedium!
                        .copyWith(color: context.tokens.muted),
                  ),
                ),
                TextButton(
                  key: const Key('undoDelete'),
                  onPressed: _restore,
                  child: Text(context.l10n.undo),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
