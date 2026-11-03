import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/result.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/group_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../models/group.dart';

/// Deletes the account. Steps, in this order: ask Google to confirm, leave every group
/// (the open marks and notices go with it; an owner leaving passes the ownership to the
/// next member, the last member leaving deletes the group), delete the personal list,
/// the profile and the account. Without Cloud Functions the client
/// does all of it, so a crash halfway can leave orphaned data (notes/decisions.md).
class DeleteAccountUseCase {
  DeleteAccountUseCase(this._accounts, this._groups, this._users);
  final AccountRepository _accounts;
  final GroupRepository _groups;
  final UserRepository _users;

  /// [slot] names the user for the account calls, [userId] is the backend id that owns
  /// the groups, the list and the profile.
  Future<Result<void>> call(String slot, String userId) async {
    final mine = await _groups.getGroupsOf(userId);
    if (mine case Failure(:final error)) return Failure(error);
    final groups = (mine as Ok<List<Group>>).value;
    final confirmed = await _accounts.reauthenticate(slot);
    if (confirmed case Failure(:final error)) return Failure(error);

    for (final g in groups.where((g) => !g.personal)) {
      final left = await _groups.leave(g.id, userId);
      if (left case Failure(:final error)) return Failure(error);
    }
    final personal = await _groups.deletePersonal(userId);
    if (personal case Failure(:final error)) return Failure(error);
    final profile = await _users.deleteProfile(userId);
    if (profile case Failure(:final error)) return Failure(error);
    return _accounts.deleteAccount(slot);
  }
}

final deleteAccountUseCaseProvider = Provider(
  (ref) => DeleteAccountUseCase(
    ref.watch(accountRepositoryProvider),
    ref.watch(groupRepositoryProvider),
    ref.watch(userRepositoryProvider),
  ),
);
