import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../view_models/groups/groups_view_model.dart';
import 'accent_dot.dart';
import 'card_sheet.dart';

/// What the user picked in the group sheet.
sealed class GroupChoice {
  const GroupChoice();
}

class SwitchGroup extends GroupChoice {
  const SwitchGroup(this.groupId);
  final String groupId;
}

class NewGroup extends GroupChoice {
  const NewGroup();
}

class JoinGroup extends GroupChoice {
  const JoinGroup();
}

class GroupSettings extends GroupChoice {
  const GroupSettings();
}

/// The switcher: the user's groups (a dot marks a notice not read yet), then the
/// ways to get another group and to manage the shown one; two floating cards.
Future<GroupChoice?> showGroupSheet(BuildContext context, String current) {
  return showCardSheet<GroupChoice>(
    context,
    builder: (_) => _GroupSheet(current: current),
    fromTop: true,
  );
}

class _GroupSheet extends ConsumerWidget {
  const _GroupSheet({required this.current});
  final String current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsViewModelProvider).value ?? const [];
    return FutureBuilder<Set<String>>(
      future: ref.read(groupsViewModelProvider.notifier).unreadGroupIds(),
      builder: (context, snapshot) {
        final unread = snapshot.data ?? const <String>{};
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetCard(
              children: [
                for (final group in groups)
                  ListTile(
                    title: Text(group.name),
                    trailing: group.id == current
                        ? const Icon(Icons.check)
                        : unread.contains(group.id)
                        ? const AccentDot(key: Key('unreadDot'), size: 10)
                        : null,
                    onTap: () =>
                        Navigator.of(context).pop(SwitchGroup(group.id)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SheetCard(
              children: [
                ListTile(
                  title: const Text('New group'),
                  onTap: () => Navigator.of(context).pop(const NewGroup()),
                ),
                ListTile(
                  title: const Text('Join group'),
                  onTap: () => Navigator.of(context).pop(const JoinGroup()),
                ),
                if (groups.any((g) => g.id == current && !g.personal))
                  ListTile(
                    title: const Text('Group settings'),
                    onTap: () =>
                        Navigator.of(context).pop(const GroupSettings()),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
