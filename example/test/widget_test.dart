// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

// ignore_for_file: avoid_print

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    //
  });

  group('raw', () {
    test('int filled with zero?', () {
      int timestamp = DateTime.now().millisecondsSinceEpoch;
      String mHex = timestamp.toRadixString(16);
      mHex = mHex.length % 2 != 0 ? '0$mHex' : mHex;

      List<int> list = [timestamp];
      Uint8List uint8list = Uint8List.fromList(list);
      Uint64List uint64list = Uint64List.fromList(list);
      print('uint8list: $uint8list, uint64list: $uint64list');
      print('debug and set a breakpoint here for inspecting.');
    });
  });
}
