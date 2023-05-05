import 'package:intl/intl.dart';

class DateUtil {
  static bool isToday(DateTime date) {
    return isSameDay(date, DateTime.now());
  }

  static bool isTodayMillis(int millis, {bool isUtc = false}) {
    return isSameDay(DateTime.fromMillisecondsSinceEpoch(millis, isUtc: isUtc), DateTime.now());
  }

  static bool isYesterday(DateTime date) {
    return isSameDay(date, DateTime.now().subtract(const Duration(days: 1)));
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

  /// If same week with today
  static bool isThisWeek(DateTime d) {
    return isSameWeek(d, DateTime.now());
  }

  /// Start from Monday to Sunday
  static bool isSameWeek(DateTime date1, DateTime date2) {
    return isSameDay(getMondayStart(date1), getMondayStart(date2));
  }

  /// The start of date, set HH:mm:ss to 00:00:00
  static DateTime getStart(DateTime d) {
    return DateTime(d.year, d.month, d.day);
  }

  /// The over of date, set HH:mm:ss to 23:59:59
  static DateTime getOver(DateTime d) {
    return d.add(Duration(days: 1)).subtract(Duration(milliseconds: 1));
  }

  /// Day and month values begin at 1, and the week starts on Monday.
  /// That is, the constants [january] and [monday] are both 1.

  /// Return Monday, set HH:mm:ss to 00:00:00
  static DateTime getMondayStart(DateTime d) {
    return getStart(d.subtract(Duration(days: d.weekday - 1)));
  }

  /// Return Sunday, set HH:mm:ss to 23:59:59
  static DateTime getSundayOver(DateTime d) {
    return getOver(d.add(Duration(days: DateTime.daysPerWeek - d.weekday)));
  }

  /// Sunday as a week begin, set HH:mm:ss to 00:00:00
  static DateTime getSundayStart(DateTime d) {
    return getStart(d.subtract(Duration(days: d.weekday == DateTime.sunday ? 0 : d.weekday)));
  }

  /// Saturday as a week end, set HH:mm:ss to 23:59:59
  static DateTime getSaturdayOver(DateTime d) {
    return getSundayStart(d).add(Duration(days: DateTime.daysPerWeek)).subtract(Duration(milliseconds: 1));
  }

  /// Reset minutes and seconds to zero
  static DateTime resetMinutesToZero(DateTime d) => DateTime(d.year, d.month, d.day, d.hour);

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

  /// Calculate by timezone offset
  static DateTime addTimezone(DateTime dateTime, int timezoneOffset) {
    return dateTime.add(Duration(hours: timezoneOffset));
  }

  static DateTime subtractTimezone(DateTime dateTime, int timezoneOffset) {
    return dateTime.subtract(Duration(hours: timezoneOffset));
  }

  /// Parse String to DateTime
  static DateTime? parse(String string, {String? pattern}) {
    try {
      return DateFormat(pattern).parse(string);
    } catch (e, s) {
      print('intl parse error $string: $e  $s');
    }
    return null;
  }

  /// Format DateTime to String
  static String format(DateTime date, {String? pattern = 'yyyy-MM-dd HH:mm:ss'}) {
    try {
      return DateFormat(pattern).format(date);
    } catch (e, s) {
      print('intl format error $date: $e  $s');
    }
    return '';
  }

  /// Format String to String with DateTime pattern
  /// 'MMM.yyyy': 'Nov.2021'
  /// 'd MMM, yyyy': '9 May, 2020'
  /// 'd MMM, yyyy HH:mm:ss': '9 May, 2020 03:30:01'
  static String translate(String string, {String? pattern = 'yyyy-MM-dd HH:mm:ss'}) {
    try {
      return format(parse(string, pattern: pattern) ?? DateTime.parse(string), pattern: pattern);
    } catch (e, s) {
      print('intl translate error $string: $e  $s');
    }
    return '';
  }
}
