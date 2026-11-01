import '../../../domain/models/purchase.dart';

/// The purchases of one calendar day of the group.
class HistoryDay {
  const HistoryDay(this.label, this.purchases);
  final String label;
  final List<Purchase> purchases;
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "14:05" in the group's zone.
String timeLabel(DateTime at, Duration utcOffset) {
  final t = at.toUtc().add(utcOffset);
  return '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
}

/// Groups [purchases] (newest first) by the day in the group's zone: "Today",
/// "Yesterday", then "Tue, 28 Oct" (with the year when it is not this year).
List<HistoryDay> groupByDay(
  List<Purchase> purchases,
  Duration utcOffset,
  DateTime now,
) {
  DateTime dayOf(DateTime at) {
    final t = at.toUtc().add(utcOffset);
    return DateTime.utc(t.year, t.month, t.day);
  }

  final today = dayOf(now);
  String label(DateTime day) {
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    final base =
        '${_weekdays[day.weekday - 1]}, ${day.day} ${_months[day.month - 1]}';
    return day.year == today.year ? base : '$base ${day.year}';
  }

  final days = <DateTime, List<Purchase>>{};
  for (final p in purchases) {
    days.putIfAbsent(dayOf(p.markedAt), () => []).add(p);
  }
  return [for (final e in days.entries) HistoryDay(label(e.key), e.value)];
}
