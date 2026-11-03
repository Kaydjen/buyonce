import 'package:intl/intl.dart';

import '../../../domain/models/purchase.dart';

/// The purchases of one calendar day of the group.
class HistoryDay {
  const HistoryDay(this.label, this.purchases);
  final String label;
  final List<Purchase> purchases;
}

/// "14:05" in the group's zone (24 hours in every supported language).
String timeLabel(DateTime at, Duration utcOffset) {
  final t = at.toUtc().add(utcOffset);
  return '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
}

/// Groups [purchases] (newest first) by the day in the group's zone: [today],
/// [yesterday], then "Tue, 28 Oct" in [locale] (with the year when it is not this year).
List<HistoryDay> groupByDay(
  List<Purchase> purchases,
  Duration utcOffset,
  DateTime now, {
  String locale = 'en',
  String today = 'Today',
  String yesterday = 'Yesterday',
}) {
  DateTime dayOf(DateTime at) {
    final t = at.toUtc().add(utcOffset);
    return DateTime.utc(t.year, t.month, t.day);
  }

  final todayDay = dayOf(now);
  final withoutYear = DateFormat('EEE, d MMM', locale);
  final withYear = DateFormat('EEE, d MMM y', locale);
  String label(DateTime day) {
    final diff = todayDay.difference(day).inDays;
    if (diff == 0) return today;
    if (diff == 1) return yesterday;
    return (day.year == todayDay.year ? withoutYear : withYear).format(day);
  }

  final days = <DateTime, List<Purchase>>{};
  for (final p in purchases) {
    days.putIfAbsent(dayOf(p.markedAt), () => []).add(p);
  }
  return [for (final e in days.entries) HistoryDay(label(e.key), e.value)];
}
