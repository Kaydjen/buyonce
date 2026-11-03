/// Every product, trip and plan belongs to a group (for example the owner and his
/// mother). A group has any number of members; its owner manages it.
const defaultGroupId = 'home';

/// Id of the personal list of [userId].
String personalGroupId(String userId) => 'personal-$userId';

class Group {
  const Group({
    required this.id,
    required this.name,
    required this.utcOffset,
    required this.ownerId,
    required this.memberIds,
    required this.inviteCode,
    this.mutedUserIds = const {},
    this.personal = false,
  });

  final String id;
  final String name;

  /// Fixed offset of the group's time zone; daylight saving is ignored until a real
  /// time zone database arrives with the backend.
  final Duration utcOffset;

  /// The member who can rename the group, remove members and delete it.
  final String ownerId;
  final List<String> memberIds;

  /// What another user types to join.
  final String inviteCode;

  /// Members who turned notifications of this group off (a stored flag until push exists).
  final Set<String> mutedUserIds;

  /// The user's own list: one member, no invite code, cannot be left or deleted. It
  /// takes the device's time zone.
  final bool personal;

  Group copyWith({
    String? name,
    Duration? utcOffset,
    String? ownerId,
    List<String>? memberIds,
    Set<String>? mutedUserIds,
  }) => Group(
    id: id,
    name: name ?? this.name,
    utcOffset: utcOffset ?? this.utcOffset,
    ownerId: ownerId ?? this.ownerId,
    memberIds: memberIds ?? this.memberIds,
    inviteCode: inviteCode,
    mutedUserIds: mutedUserIds ?? this.mutedUserIds,
    personal: personal,
  );
}

/// Why a group action failed.
enum GroupError {
  notFound,
  unknownCode,
  notOwner,
  emptyName,
  personalList,
  full,

  /// The server cannot be reached (or answered too late).
  offline,
  failed,
}

/// A group holds at most this many members (the security rules enforce it too).
const maxGroupMembers = 20;

/// DEBUG: hour of the group's local day at which the Bought list is cleared (0 = midnight).
/// Raise it to the current hour on the phone to see marks made earlier disappear.
const boughtDayStartHour = 0;

/// The latest moment not after [now] at which the group's day starts. Marks before it
/// belong to a past day.
DateTime dayStart(DateTime now, Duration utcOffset) {
  final local = now.toUtc().add(utcOffset);
  var start = DateTime.utc(
    local.year,
    local.month,
    local.day,
    boughtDayStartHour,
  );
  if (start.isAfter(local)) start = start.subtract(const Duration(days: 1));
  return start.subtract(utcOffset);
}

/// The two fake users of every group until real accounts exist; the debug switch
/// changes between them.
const groupUserIds = ['me', 'partner'];
