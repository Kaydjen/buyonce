import '../../core/utils/result.dart';
import '../../domain/models/group.dart';

/// Storage of groups and their members. The in-memory service serves the fake users
/// and tests; the Firestore service serves the real signed-in user.
///
/// Authorisation (who may rename, remove, delete) is decided by the repository and, on
/// the server, again by the security rules; the service only does what it is told.
abstract class GroupService {
  /// Local-first writes (rename, mute) that the server refused after they were shown.
  Stream<Object> get writeErrors;

  /// Groups [userId] belongs to, in the order they were created; emits the current
  /// value to a new listener, then after every change.
  Stream<Result<List<Group>>> watchGroups(String userId);

  Future<Result<List<Group>>> getGroups(String userId);

  /// [GroupError.notFound] when the group does not exist (or the user cannot see it).
  Future<Result<Group>> getGroup(String groupId);

  /// A new group with a fresh invite code (none for a personal list); [ownerId] is its
  /// only member.
  Future<Result<Group>> create({
    required String id,
    required String name,
    required Duration utcOffset,
    required String ownerId,
    bool personal = false,
  });

  /// Adds [userId] to the group with this code (already normalised: trimmed, upper
  /// case). A user who is a member already changes nothing. Fails with
  /// [GroupError.unknownCode] or [GroupError.full].
  Future<Result<Group>> join(String code, String userId);

  Future<Result<void>> rename(String groupId, String name);

  /// Removes the member; [newOwnerId] (an existing member) becomes the owner in the
  /// same step, for an owner who leaves.
  Future<Result<void>> removeMember(
    String groupId,
    String userId, {
    String? newOwnerId,
  });

  Future<Result<void>> setMuted(String groupId, String userId, bool muted);

  /// Removes the group with its members.
  Future<Result<void>> delete(String groupId);
}
