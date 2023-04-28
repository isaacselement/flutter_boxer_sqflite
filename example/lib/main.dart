import 'dart:async';

import 'package:example/app.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

void main() {
  /// Flutter Error Report
  FlutterError.onError = (FlutterErrorDetails details) {
    assert(() {
      print('@@@@@@ Flutter Error: ${details.exception}, ${details.stack}');
      return true;
    }());
  };

  /// Run App
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: App(),
    ),
  );

  // runZonedGuarded(
  //   () {
  //     /// Run App
  //     runApp(
  //       MaterialApp(
  //         debugShowCheckedModeBanner: false,
  //         home: App(),
  //       ),
  //     );
  //   },
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
