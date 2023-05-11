import 'package:example/app.dart';
import 'package:flutter/material.dart';

void main() {
  /// Print the entry point of the program
  () async {
    print('Process started from `main` function');
  }();

  /// Flutter Error Report
  FlutterError.onError = (FlutterErrorDetails details) {
    assert(() {
      print('@@@@@@ Flutter Error: ${details.exception}, ${details.stack}');
      return true;
    }());
  };

  /// Run App
  void runApplication() {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: App(),
      ),
    );
  }

  /// Run without Zone
  runApplication();

  /// Run with Zone
  // runZonedGuarded(
  //   runApplication,
  //
  //   /// Unhandled Exception
  //   (Object error, StackTrace stack) {
  //     assert(() {
  //       print('@@@@@@ Unhandled Exception: $error, $stack');
  //       return true;
  //     }());
  //   },
  // );
}
