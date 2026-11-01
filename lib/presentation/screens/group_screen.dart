import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../domain/models/group.dart';
import '../view_models/groups/groups_view_model.dart';
import '../view_models/session/session.dart';
import '../view_models/users/user_names_view_model.dart';
import '../widgets/group_dialogs.dart';
import '../widgets/section_label.dart';

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
    // The group is gone (left or deleted): the screen closes itself.
    if (group == null) return const Scaffold();
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
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          context.tokens.gutter,
          8,
          context.tokens.gutter,
          24,
        ),
        children: [
          const SectionLabel('Members'),
          for (final id in group.memberIds)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(ref.watch(userNameProvider(id))),
              subtitle: Text(
                [
                  if (id == group.ownerId) 'Owner',
                  if (id == userId) 'You',
                ].join(' · '),
                style: TextStyle(color: context.tokens.muted),
              ),
              trailing: owner && id != group.ownerId
                  ? TextButton(
                      key: Key('remove-$id'),
                      onPressed: () => _remove(context, ref, vm, group, id),
                      child: const Text('Remove'),
                    )
                  : null,
            ),
          const SizedBox(height: 16),
          const SectionLabel('Invite code'),
          Row(
            children: [
              Text(
                group.inviteCode,
                key: const Key('inviteCode'),
                style: Theme.of(context).textTheme.headlineSmall!
                    .copyWith(letterSpacing: 4),
              ),
              const Spacer(),
              IconButton(
                key: const Key('copyCode'),
                onPressed: () => _copy(context, group.inviteCode),
                icon: const Icon(Icons.copy),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            key: const Key('muteGroup'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Mute notifications'),
            value: group.mutedUserIds.contains(userId),
            onChanged: (muted) => vm.setMuted(group.id, muted),
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
    );
  }

  Future<void> _copy(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Code copied')));
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
    if (sure) await vm.removeMember(group.id, memberId);
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
    await vm.leave(group.id);
    if (context.mounted) Navigator.of(context).pop();
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
    await vm.delete(group.id);
    if (context.mounted) Navigator.of(context).pop();
  }
}
