// Helpers for week-aligned date math. Used by weekly XP reset + leaderboard.
//
// Convention: weeks start on Monday (weekday = DateTime.monday = 1).
// Sunday is weekday = 7.

/// Returns Monday 00:00 (local time) of the week containing [d].
///
/// Strips time-of-day; the returned DateTime has hour/minute/second/ms/us = 0.
DateTime mondayOf(DateTime d) {
  return DateTime(d.year, d.month, d.day - (d.weekday - 1));
}

/// Returns `yyyy-MM-dd` formatted string for `mondayOf(d)`.
String mondayStringOf(DateTime d) {
  final m = mondayOf(d);
  final mm = m.month.toString().padLeft(2, '0');
  final dd = m.day.toString().padLeft(2, '0');
  return '${m.year}-$mm-$dd';
}
