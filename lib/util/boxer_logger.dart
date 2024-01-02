typedef BoxerFatalError = void Function(/* Object */ dynamic exception, /* StackTrace? */ dynamic stack);
typedef BoxerLoggerFunc = void Function(int level, String tag, String message);
typedef BoxerMarkerFunc = void Function(int flag, String? tag, Object? object);

class BoxerLogger {
  static const String TAG = 'BoxerLogger';

  static Map<int, String> levelMap = const {0: 'V', 1: 'D', 2: 'I', 3: 'W', 4: 'E', 5: 'F'};

  static BoxerLoggerInstance instance = BoxerLoggerInstance();

  /// verbose log
  static void v(String? tag, String message) => instance.v(tag, message);

  /// debug log
  static void d(String? tag, String message) => instance.d(tag, message);

  /// info log
  static void i(String? tag, String message) => instance.i(tag, message);

  /// warning log
  static void w(String? tag, String message) => instance.w(tag, message);

  /// error log
  static void e(String? tag, String message) => instance.e(tag, message);

  /// fatal log
  static void f(String? tag, String message) => instance.f(tag, message);

  /// External Logger function
  static set logger(BoxerLoggerFunc? logger) => instance.logger = logger;

  /// External Marker, for some benchmark
  static set marker(BoxerMarkerFunc? marker) => instance.marker = marker;

  static void mark({int flag = 0, String? tag, Object? object}) => instance.mark(flag: flag, tag: tag, object: object);

  /// Database operations error handler, execute or query sql etc...
  static set fatalReporter(BoxerFatalError? fatalReporter) => instance.fatalReporter = fatalReporter;

  static void reportFatal(dynamic e, dynamic s) => instance.reportFatal(e, s);

  /// https://dart.dev/guides/language/language-tour#assert
  /// Only print and evaluate the expression function on debug mode, will omit in production/profile mode
  static void console(String Function() expr) => instance.console(expr);
}

class BoxerLoggerInstance {
  String mTAG = BoxerLogger.TAG;

  /// verbose log
  void v(String? tag, String message) {
    _log(0, tag, message);
  }

  /// debug log
  void d(String? tag, String message) {
    _log(1, tag, message);
  }

  /// info log
  void i(String? tag, String message) {
    _log(2, tag, message);
  }

  /// warning log
  void w(String? tag, String message) {
    _log(3, tag, message);
  }

  /// error log
  void e(String? tag, String message) {
    _log(4, tag, message);
  }

  /// fatal log
  void f(String? tag, String message) {
    _log(5, tag, message);
  }

  /// External Logger function
  BoxerLoggerFunc? logger;

  void _log(int level, String? tag, String message) {
    tag ??= mTAG;
    if (logger != null) {
      logger!(level, tag, message);
      return;
    }
    assert(() {
      print("${BoxerLogger.levelMap[level]}/${DateTime.now()}: [$tag] $message");
      return true;
    }());
  }

  /// External Marker, for some benchmark
  BoxerMarkerFunc? marker;

  void mark({int flag = 0, String? tag, Object? object}) => marker?.call(flag, tag, object);

  /// Database operations error handler, execute or query sql etc...
  BoxerFatalError? fatalReporter;

  void reportFatal(dynamic e, dynamic s) => fatalReporter?.call(e, s);

  /// https://dart.dev/guides/language/language-tour#assert
  /// Only print and evaluate the expression function on debug mode, will omit in production/profile mode
  void console(String Function() expr) {
    assert(() {
      print("${DateTime.now()}: ${expr()}");
      return true;
    }());
  }
}
