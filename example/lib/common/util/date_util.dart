import 'package:intl/intl.dart';

class DateUtil {
  static bool isToday(int milliseconds, {bool isUtc = false}) {
    if (milliseconds == 0) return false;
    DateTime now = isUtc ? DateTime.now().toUtc() : DateTime.now().toLocal();
    DateTime date = DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: isUtc);
    return isSameDay(date, now);
  }

  static bool isYesterday(DateTime date) {
    DateTime yesterday = DateTime.now().subtract(const Duration(days: 1));
    return isSameDay(date, yesterday);
  }

  /// If same week with today
  static bool isThisWeek(DateTime date) {
    return isSameWeek(date, DateTime.now());
  }

  /// Start from Monday to Sunday
  static bool isSameWeek(DateTime date1, DateTime date2) {
    return isSameDay(getMondayBegin(date1), getMondayBegin(date2));
  }

  static bool isSameDay(DateTime date1, DateTime date2) {
    return isSameMonth(date1, date2) && date2.day == date1.day;
  }

  static bool isSameMonth(DateTime date1, DateTime date2) {
    return isSameYear(date1, date2) && date2.month == date1.month;
  }

  static bool isSameYear(DateTime date1, DateTime date2) {
    return date2.year == date1.year;
  }

  /// The start of date
  static DateTime getStart(DateTime d) {
    return DateTime(d.year, d.month, d.day);
  }

  /// The over of date
  static DateTime getOver(DateTime d) {
    return DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
  }

  /// Return Monday
  static DateTime getMondayBegin(DateTime d) {
    // start from Monday. i.e 2019-10-07 00:00:00.000
    return getStart(d.subtract(Duration(days: d.weekday - 1)));
  }

  /// Return Sunday
  static DateTime getSundayOver(DateTime d) {
    // end with next Monday. i.e 2019-10-14 00:00:00.000 minus 1 millis second
    return getStart(d.add(Duration(days: DateTime.daysPerWeek - d.weekday)));
  }

  /// Return Sunday, and set HH:mm:ss to 0
  static DateTime getSundayBegin(DateTime d) {
    int weekIndex = d.weekday;
    if (d.weekday == DateTime.sunday) {
      weekIndex = 0;
    }
    final startDate = d.subtract(Duration(days: weekIndex));
    return DateTime(startDate.year, startDate.month, startDate.day);
  }

  /// Return Saturday, and set HH:mm:ss to 59
  static DateTime getSaturdayOver(DateTime d) {
    int weekIndex = d.weekday;
    if (d.weekday == DateTime.sunday) {
      weekIndex = 0;
    }
    final endDate = d.add(Duration(days: DateTime.daysPerWeek - weekIndex));
    return DateTime(endDate.year, endDate.month, endDate.day).subtract(const Duration(seconds: 1));
  }

  /// Reset minute and second to zero
  static DateTime resetSecondsToZero(DateTime d) => DateTime(d.year, d.month, d.day, d.hour, 0);

  /// Get DateTime By Milliseconds.
  static DateTime getDateTimeByMillis(int millis, {bool isUtc = false}) => DateTime.fromMillisecondsSinceEpoch(millis, isUtc: isUtc);

  /// Compare hour and minute
  static bool isBefore(String a, String b) {
    List<String> aList = a.split(":");
    List<String> bList = b.split(":");
    int aHour = int.parse(aList.first);
    int bHour = int.parse(bList.first);
    if (aHour < bHour) {
      return true;
    } else if (aHour == bHour) {
      int aMin = int.parse(aList.last);
      int bMin = int.parse(bList.last);
      if (aMin < bMin) {
        return true;
      } else {
        return false;
      }
    } else {
      return false;
    }
  }

  /// Return by timezone
  static DateTime addTimezone(DateTime dateTime, int timezoneOffset) {
    return dateTime.add(Duration(hours: timezoneOffset));
  }

  /// Parse string to DateTime
  static DateTime? parse(String string, {String? pattern}) {
    try {
      return DateFormat(pattern).parse(string);
    } catch (e, s) {
      print('intl parse error $string: $e  $s');
    }
    return null;
  }

  /// 'd MMM, yyyy HH:mm:ss': '9 May, 2020 03:30:01', 'd MMM, yyyy': '9 May, 2020', 'MMM.yyyy': 'Nov.2021'
  static String translate(String string, {String? pattern = 'yyyy-MM-dd HH:mm:ss'}) {
    return formatString(string, pattern: pattern);
  }

  static String format(DateTime date, {String? pattern = 'yyyy-MM-dd HH:mm:ss'}) {
    try {
      return DateFormat(pattern).format(date);
    } catch (e, s) {
      print('intl format error $date: $e  $s');
    }
    return '';
  }

  static String formatString(String string, {String? pattern = 'yyyy-MM-dd HH:mm:ss'}) {
    if (string.isEmpty) return '';
    try {
      DateTime dateTime = parse(string, pattern: pattern) ?? DateTime.parse(string);
      return format(dateTime, pattern: pattern);
    } catch (e, s) {
      print('intl formatString error $string: $e  $s');
    }
    return '';
  }
}
