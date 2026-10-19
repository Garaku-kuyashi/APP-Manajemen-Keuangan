import 'package:intl/intl.dart';

abstract final class DashboardDateFormatter {
  static final DateFormat _todayFormat =
      DateFormat('EEE, d MMMM yyyy', 'id_ID');

  static final DateFormat _shortDateFormat =
      DateFormat('d MMM yyyy', 'id_ID');

  static String today() => _todayFormat.format(DateTime.now());

  static String shortDate(DateTime date) =>
      _shortDateFormat.format(date);
}