import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../view_models/groups/groups_view_model.dart';
import '../view_models/history/history_days.dart';
import '../view_models/history/history_view_model.dart';
import '../view_models/session/session.dart';
import '../view_models/users/user_names_view_model.dart';
import '../widgets/titled_card.dart';
import '../widgets/edge_fade.dart';

/// What was bought, by day and with the time of the mark. Your own purchases carry no
/// name; other members' purchases do.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyViewModelProvider);
    final me = ref.watch(currentUserIdProvider);
    final activeId = ref.watch(activeGroupIdProvider);
    final offset =
        ref
            .watch(groupsViewModelProvider)
            .value
            ?.where((g) => g.id == activeId)
            .firstOrNull
            ?.utcOffset ??
        DateTime.now().timeZoneOffset;
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: switch (history) {
        AsyncData(:final value) when value.isEmpty => Center(
          child: Text(
            'No purchases yet',
            style: TextStyle(color: context.tokens.muted),
          ),
        ),
        AsyncData(:final value) => EdgeFade(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              context.tokens.gutter,
              context.tokens.listTopPadding,
              context.tokens.gutter,
              24,
            ),
            children: [
              for (final day in groupByDay(value, offset, DateTime.now())) ...[
                TitledCard(
                  title: day.label,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Column(
                    children: [
                      for (final p in day.purchases)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p.productName,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                p.userId == me
                                    ? timeLabel(p.markedAt, offset)
                                    : '${ref.watch(userNameProvider(p.userId))}  '
                                          '${timeLabel(p.markedAt, offset)}',
                                style: TextStyle(color: context.tokens.muted),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
        AsyncError() => const Center(child: Text('Failed to load')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
