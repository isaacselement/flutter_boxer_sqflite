import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';
import 'package:flutter_dialog_shower/flutter_dialog_shower.dart';

class WidgetUtil {
  /// Edit Box

  static get _editorBoxWidth => 400 >= ScreensUtils.screenWidth ? ScreensUtils.screenWidth - 100 : 400.toDouble();

  static get _editorBoxHeight => 300 >= ScreensUtils.screenWidth ? ScreensUtils.screenWidth - 100 : 300.toDouble();

  static Widget newEditBox({double? width, double? height, TextEditingController? controller}) {
    return Container(
      width: width ?? _editorBoxWidth,
      height: height ?? _editorBoxHeight,
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.all(2),
      // decoration: BoxDecoration(border: Border.all(color: Colors.grey, width: 1)),
      child: Scrollbar(
        child: SingleChildScrollView(
          child: Column(
            children: [
              CupertinoTextField.borderless(
                controller: controller,
                style: const TextStyle(fontSize: 15, color: Colors.black),
                padding: const EdgeInsets.all(6.0),
                placeholder: 'Click Here For Get Focus First ...',
                maxLines: 100,
                onChanged: (str) {
                  BoxerLogger.d('WidgetUtil', 'You enter text: $str');
                },
              )
            ],
          ),
        ),
      ),
    );
  }

  /// Folder Widgets

  static Map<State, Btv<bool>> collapsedBtvMap = {};
  static Map<State, AnimationController> collapsedAnimationControllerMap = {};

  static Widget createExpandableWidget({
    required Widget child,
    String expandText = 'Expand',
    String collapseText = 'Collapse',
  }) {
    return BuilderWithTicker(
      init: (state) {
        collapsedAnimationControllerMap[state] = AnimationController(
          duration: const Duration(milliseconds: 250),
          vsync: state as BuilderWithTickerState,
          value: collapsedBtvMap.isNotEmpty ? 0 : 1,
        );
        collapsedBtvMap[state] ??= Btv<bool>(collapsedBtvMap.isNotEmpty);
      },
      dispose: (state) {
        collapsedAnimationControllerMap[state]?.dispose();
        collapsedAnimationControllerMap.remove(state);
        collapsedBtvMap.remove(state);
      },
      builder: (State<StatefulWidget> state) {
        return Column(
          children: [
            WidgetUtil.createExpandableTipsWidget(
              isCollapsedBtv: collapsedBtvMap[state],
              controller: collapsedAnimationControllerMap[state],
              expandText: expandText,
              collapseText: collapseText,
            ),
            SizeTransition(
              axisAlignment: -1,
              axis: Axis.vertical,
              sizeFactor: CurvedAnimation(
                curve: Curves.fastOutSlowIn,
                parent: collapsedAnimationControllerMap[state]!,
              ),
              child: child,
            ),
            SizedBox(height: 8),
          ],
        );
      },
    );
  }

  static Widget createExpandableTipsWidget({
    required Btv<bool>? isCollapsedBtv,
    AnimationController? controller,
    String expandText = 'Expand',
    String collapseText = 'Collapse',
  }) {
    return Btw(
      builder: (context) {
        return CupertinoButton(
          color: Colors.transparent,
          padding: EdgeInsets.zero,
          minSize: 32,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isCollapsedBtv?.value ?? false ? expandText : collapseText,
                style: const TextStyle(color: Colors.blue, fontSize: 12),
              ),
              const SizedBox(width: 5),
              RotatedBox(
                quarterTurns: isCollapsedBtv?.value ?? false ? 1 : -1,
                child: const Icon(Icons.arrow_forward_ios, color: Colors.blue, size: 12),
              ),
            ],
          ),
          onPressed: () {
            isCollapsedBtv?.value ?? false ? controller?.forward() : controller?.reverse();
            isCollapsedBtv?.value = !isCollapsedBtv.value;
          },
        );
      },
    );
  }

  /// Dialog Widgets

  static void showActionSheet({required List<Map> sheet, double? itemWidth}) {
    DialogWrapper.showBottom(ActionSheetButtons(
      items: sheet,
      itemWidth: itemWidth ?? 380,
      itemSpacing: 10,
      itemInnerBuilder: (i, e) {
        Map map = sheet[i];
        TextStyle style = const TextStyle(color: Color(0xFF1C1D21), fontSize: 16);
        return Row(
          children: [
            const SizedBox(width: 50),
            Icon(map['icon'] as IconData),
            const SizedBox(width: 20),
            Text(map['text'], style: style),
          ],
        );
      },
      funcOfItemOnTapped: (i, e) {
        Map map = sheet[i];
        Function(Map map) func = map['event'];
        func.call(map);
        return false;
      },
    ))
      ..barrierDismissible = true
      ..containerBorderRadius = 1.0
      ..containerBackgroundColor = Colors.transparent
      ..containerShadowColor = Colors.transparent;
  }
}
