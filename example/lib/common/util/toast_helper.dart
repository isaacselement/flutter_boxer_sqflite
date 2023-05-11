import 'package:flutter/material.dart';
import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';
import 'package:flutter_dialog_shower/flutter_dialog_shower.dart';

class ToastHelper {
  static OverlayShower showRed(String message) {
    return showColor(message, textStyle: const TextStyle(color: Colors.red));
  }

  static OverlayShower showGreen(String message) {
    return showColor(message, textStyle: const TextStyle(color: Colors.green));
  }

  static OverlayShower showColor(
    String message, {
    TextStyle? textStyle,
    bool isStateful = false,
    Duration? duration = const Duration(milliseconds: 3000),
  }) {
    return show(message, textStyle: textStyle, isStateful: isStateful, duration: duration);
  }

  static OverlayShower show(
    String message, {
    TextStyle? textStyle,
    bool isStateful = false,
    Duration? duration = const Duration(milliseconds: 3000),
  }) {
    BoxerLogger.d('ToastHelper', '>>>>> $message');
    return OverlayWidgets.showToast(
      message,
      textStyle: textStyle,
      isStateful: isStateful,
      onScreenDuration: duration,
      shadow: const BoxShadow(),
    )
      ..alignment = Alignment.topCenter
      ..margin = const EdgeInsets.only(top: 50);
  }

  static OverlayShower showError(e, s) {
    return show('Exception:\n$e\n$s\n');
  }
}
