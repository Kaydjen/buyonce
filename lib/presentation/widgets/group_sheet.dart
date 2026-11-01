import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../view_models/groups/groups_view_model.dart';

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
/// ways to get another group and to manage the shown one.
Future<GroupChoice?> showGroupSheet(BuildContext context, String current) {
  return showModalBottomSheet<GroupChoice>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _GroupSheet(current: current),
  );
}

class _GroupSheet extends ConsumerWidget {
  const _GroupSheet({required this.current});
  final String current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsViewModelProvider).value ?? const [];
    return SafeArea(
      child: SingleChildScrollView(
        child: FutureBuilder<Set<String>>(
          future: ref.read(groupsViewModelProvider.notifier).unreadGroupIds(),
          builder: (context, snapshot) {
            final unread = snapshot.data ?? const <String>{};
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final group in groups)
                  ListTile(
                    title: Text(group.name),
                    trailing: group.id == current
                        ? const Icon(Icons.check)
                        : unread.contains(group.id)
                        ? const _UnreadDot()
                        : null,
                    onTap: () =>
                        Navigator.of(context).pop(SwitchGroup(group.id)),
                  ),
                const Divider(),
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
            );
          },
        ),
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('unreadDot'),
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: context.tokens.text,
      shape: BoxShape.circle,
    ),
  );
}
