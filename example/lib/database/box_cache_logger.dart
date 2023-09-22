import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';

class BoxCacheLogger {
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
  void Function(int level, String tag, String message)? logger;

  void _log(int level, String? tag, String message) {
    tag ??= 'BoxCacheLogger';
    if (logger != null) {
      logger!(level, tag, message);
      return;
    }
    assert(() {
      print('${BoxerLogger.levelToString(level)}/${DateTime.now()}: [$tag] $message');
      return true;
    }());
  }

  /// External Fatal Error Logger function
  void Function(dynamic exception, dynamic stack)? fatalLogger;

  void fatal(dynamic e, dynamic s) => fatalLogger?.call(e, s);

  /// External Marker, for some benchmark
  void Function(int flag, String tag, Object? object)? marker;

  void mark({int flag = 0, String tag = '', Object? object}) => marker?.call(flag, tag, object);
}
