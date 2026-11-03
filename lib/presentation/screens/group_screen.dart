import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/result.dart';
import '../../domain/models/group.dart';
import '../view_models/groups/groups_view_model.dart';
import '../view_models/session/session.dart';
import '../view_models/users/user_names_view_model.dart';
import '../widgets/group_dialogs.dart';
import '../widgets/groove.dart';
import '../widgets/soft_switch_tile.dart';
import '../widgets/titled_card.dart';
import '../widgets/edge_fade.dart';
import '../widgets/toast.dart';

/// One group: members, invite code, mute, leave and (for the owner) rename, remove
/// members and delete.
class GroupScreen extends ConsumerWidget {
  const GroupScreen({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref
        .watch(groupsViewModelProvider)
        .value
        ?.where((g) => g.id == groupId)
        .firstOrNull;
    final userId = ref.watch(currentUserIdProvider);
    // The group is gone (left, deleted or removed elsewhere): close the screen.
    if (group == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold();
    }
    final owner = group.ownerId == userId;
    final vm = ref.read(groupsViewModelProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: Text(group.name),
        actions: [
          if (owner)
            TextButton(
              key: const Key('renameGroup'),
              onPressed: () => showRenameGroupDialog(context, ref, group),
              child: const Text('Rename'),
            ),
        ],
      ),
      body: EdgeFade(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            context.tokens.gutter,
            context.tokens.listTopPadding,
            context.tokens.gutter,
            24,
          ),
          children: [
            TitledCard(
              title: 'Members',
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (final id in group.memberIds) ...[
                    if (id != group.memberIds.first) const Groove(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(ref.watch(userNameProvider(id))),
                      subtitle: id == group.ownerId || id == userId
                          ? Text(
                              [
                                if (id == group.ownerId) 'Owner',
                                if (id == userId) 'You',
                              ].join(' · '),
                              style: TextStyle(color: context.tokens.muted),
                            )
                          : null,
                      trailing: owner && id != group.ownerId
                          ? TextButton(
                              key: Key('remove-$id'),
                              onPressed: () =>
                                  _remove(context, ref, vm, group, id),
                              child: const Text('Remove'),
                            )
                          : null,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            TitledCard(
              title: 'Invite code',
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            group.inviteCode,
                            key: const Key('inviteCode'),
                            style: Theme.of(context).textTheme.headlineSmall!
                                .copyWith(letterSpacing: 4),
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('copyCode'),
                        tooltip: 'Copy code',
                        onPressed: () => _copy(context, group.inviteCode),
                        icon: const Icon(Icons.copy),
                      ),
                    ],
                  ),
                  const Groove(),
                  SoftSwitchTile(
                    key: const Key('muteGroup'),
                    title: 'Mute notifications',
                    value: group.mutedUserIds.contains(userId),
                    onChanged: (muted) => vm.setMuted(group.id, muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              key: const Key('leaveGroup'),
              onPressed: () => _leave(context, vm, group),
              child: const Text('Leave group'),
            ),
            if (owner)
              TextButton(
                key: const Key('deleteGroup'),
                onPressed: () => _delete(context, vm, group),
                child: const Text('Delete group'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    showToast(context, 'Code copied');
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    GroupsViewModel vm,
    Group group,
    String memberId,
  ) async {
    final name = ref.read(userNameProvider(memberId));
    final sure = await confirmAction(
      context,
      title: 'Remove $name?',
      body: '$name stops seeing ${group.name}.',
      confirm: 'Remove $name',
      keep: 'Keep $name',
    );
    if (!sure) return;
    final result = await vm.removeMember(group.id, memberId);
    if (result case Failure(:final error) when context.mounted) {
      showToast(context, groupErrorText(error));
    }
  }

  Future<void> _leave(
    BuildContext context,
    GroupsViewModel vm,
    Group group,
  ) async {
    final sure = await confirmAction(
      context,
      title: 'Leave ${group.name}?',
      body: 'You stop seeing its lists.',
      confirm: 'Leave group',
      keep: 'Stay',
    );
    if (!sure) return;
    final result = await vm.leave(group.id);
    if (!context.mounted) return;
    if (result case Failure(:final error)) {
      showToast(context, groupErrorText(error));
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete(
    BuildContext context,
    GroupsViewModel vm,
    Group group,
  ) async {
    final sure = await confirmAction(
      context,
      title: 'Delete ${group.name}?',
      body: 'Its lists and plans are deleted for everyone.',
      confirm: 'Delete group',
      keep: 'Keep group',
    );
    if (!sure) return;
    final result = await vm.delete(group.id);
    if (!context.mounted) return;
    if (result case Failure(:final error)) {
      showToast(context, groupErrorText(error));
    } else {
      Navigator.of(context).pop();
    }
  }
}
