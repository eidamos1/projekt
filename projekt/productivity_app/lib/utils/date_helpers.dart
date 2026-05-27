import 'package:intl/intl.dart';

String formatDate(DateTime date) {
  return DateFormat('yyyy-MM-dd').format(date);
}

String todayString() {
  return formatDate(DateTime.now());
}

String yesterdayString() {
  return formatDate(DateTime.now().subtract(const Duration(days: 1)));
}

String tomorrowString() {
  return formatDate(DateTime.now().add(const Duration(days: 1)));
}

DateTime parseDate(String dateStr) {
  return DateFormat('yyyy-MM-dd').parse(dateStr);
}

/// Returns 'yyyy-MM-dd HH:mm' for the current local time. 16-char format.
String nowMinuteString() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')} '
      '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
}

/// Parses either 'yyyy-MM-dd' (10 chars) or 'yyyy-MM-dd HH:mm' (16 chars).
/// Returns null if format unrecognized.
DateTime? parseFlexibleTimestamp(String? s) {
  if (s == null) return null;
  if (s.length == 10) {
    try { return DateFormat('yyyy-MM-dd').parse(s); } catch (_) { return null; }
  }
  if (s.length == 16) {
    try { return DateFormat('yyyy-MM-dd HH:mm').parse(s); } catch (_) { return null; }
  }
  return null;
}

/// Returns the hour from a full timestamp; null for date-only or invalid input.
int? hourOf(String? s) {
  if (s == null || s.length != 16) return null;
  return parseFlexibleTimestamp(s)?.hour;
}

/// Czech-language relative timestamp ("Před 5 min.", "Včera", "Před 3 dny",
/// "2026-05-14") for a 'yyyy-MM-dd HH:mm' string. Falls back to the raw
/// input on parse failure so the UI never goes empty.
String relativeTimeCs(String timestamp, {DateTime? now}) {
  final t = parseFlexibleTimestamp(timestamp);
  if (t == null) return timestamp;
  final n = now ?? DateTime.now();
  final diff = n.difference(t);
  if (diff.isNegative) {
    // Clock skew or future timestamp — render as the date.
    return timestamp.length >= 10 ? timestamp.substring(0, 10) : timestamp;
  }
  final minutes = diff.inMinutes;
  if (minutes < 1) return 'Právě teď';
  if (minutes < 60) return 'Před $minutes min.';
  final hours = diff.inHours;
  if (hours < 24 && t.day == n.day) return 'Před $hours hod.';
  final today = DateTime(n.year, n.month, n.day);
  final tDay = DateTime(t.year, t.month, t.day);
  final dayDiff = today.difference(tDay).inDays;
  if (dayDiff == 1) return 'Včera';
  if (dayDiff < 7) {
    if (dayDiff == 2 || dayDiff == 3 || dayDiff == 4) return 'Před $dayDiff dny';
    return 'Před $dayDiff dny';
  }
  if (dayDiff < 30) {
    final weeks = (dayDiff / 7).floor();
    if (weeks == 1) return 'Před týdnem';
    if (weeks >= 2 && weeks <= 4) return 'Před $weeks týdny';
    return 'Před $weeks týdny';
  }
  // Older — show the calendar date.
  return timestamp.length >= 10 ? timestamp.substring(0, 10) : timestamp;
}
