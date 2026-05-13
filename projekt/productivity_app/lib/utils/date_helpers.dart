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
