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
