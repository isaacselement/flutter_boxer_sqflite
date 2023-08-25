typedef BoxerFatalError = void Function(/* Object */ dynamic exception, /* StackTrace? */ dynamic stack);

class BoxerLogger {
  /// verbose log
  static void v(String? tag, String message) {
    _log(0, tag, message);
  }

  /// debug log
  static void d(String? tag, String message) {
    _log(1, tag, message);
  }

  /// info log
  static void i(String? tag, String message) {
    _log(2, tag, message);
  }

  /// warning log
  static void w(String? tag, String message) {
    _log(3, tag, message);
  }

  /// error log
  static void e(String? tag, String message) {
    _log(4, tag, message);
  }

  /// fatal log
  static void f(String? tag, String message) {
    _log(5, tag, message);
  }

  /// External Logger function
  static Function(int level, String tag, String message)? logger;

  static void _log(int level, String? tag, String message) {
    tag ??= 'BoxerLogger';
    if (logger != null) {
      logger!(level, tag, message);
      return;
    }
    assert(() {
      String prefix = BoxerLogger.levelToString(level);
      print('$prefix/${DateTime.now()}: [$tag] $message');
      return true;
    }());
  }

  static String levelToString(int level) {
    String prefix = 'V';
    switch (level) {
      case 0:
        prefix = 'V';
        break;
      case 1:
        prefix = 'D';
        break;
      case 2:
        prefix = 'I';
        break;
      case 3:
        prefix = 'W';
        break;
      case 4:
        prefix = 'E';
        break;
      case 5:
        prefix = 'F';
        break;
    }
    return prefix;
  }

  /// Database operations error handler, execute or query sql etc...
  static BoxerFatalError? onFatalError;

  static void reportFatalError(dynamic e, dynamic s) => onFatalError?.call(e, s);

  /// https://dart.dev/guides/language/language-tour#assert
  /// Only print and evaluate the expression function on debug mode, will omit in production/profile mode
  static void console(String Function() expr) {
    assert(() {
      print('${DateTime.now()}: ${expr()}');
      return true;
    }());
  }
}
