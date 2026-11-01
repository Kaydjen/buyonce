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
  });

  final String id;
  final String groupId;
  final String userId;
  final DateTime startedAt;
  final List<TripMark> marks;

  /// Null while the trip is open.
  final DateTime? sentAt;

  bool get isOpen => sentAt == null;

  Trip copyWith({List<TripMark>? marks, DateTime? sentAt}) => Trip(
    id: id,
    groupId: groupId,
    userId: userId,
    startedAt: startedAt,
    marks: marks ?? this.marks,
    sentAt: sentAt ?? this.sentAt,
  );
}
