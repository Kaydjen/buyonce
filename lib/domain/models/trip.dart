import 'trip_mark.dart';

/// A shopping session: starts with the first mark, ends when sent.
class Trip {
  const Trip({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.startedAt,
    this.marks = const [],
    this.sentAt,
    this.autoSendAt,
  });

  final String id;
  final String groupId;
  final String userId;
  final DateTime startedAt;
  final List<TripMark> marks;

  /// Null while the trip is open.
  final DateTime? sentAt;

  /// When the server sends the trip if the phone does not (cron); null: never.
  final DateTime? autoSendAt;

  bool get isOpen => sentAt == null;

  Trip copyWith({
    List<TripMark>? marks,
    DateTime? sentAt,
    DateTime? autoSendAt,
    bool clearAutoSend = false,
  }) => Trip(
    id: id,
    groupId: groupId,
    userId: userId,
    startedAt: startedAt,
    marks: marks ?? this.marks,
    sentAt: sentAt ?? this.sentAt,
    autoSendAt: clearAutoSend ? null : autoSendAt ?? this.autoSendAt,
  );
}
