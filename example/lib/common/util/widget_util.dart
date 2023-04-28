import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';
import 'package:flutter_dialog_shower/flutter_dialog_shower.dart';

class WidgetUtil {
  static get _editorBoxWidth => 400 >= SizesUtils.screenWidth ? SizesUtils.screenWidth - 100 : 400.toDouble();

  static get _editorBoxHeight => 300 >= SizesUtils.screenWidth ? SizesUtils.screenWidth - 100 : 300.toDouble();

  static Widget newEditBox({double? width, double? height, TextEditingController? controller}) {
    return Container(
      width: width ?? _editorBoxWidth,
      height: height ?? _editorBoxHeight,
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.all(2),
      // decoration: BoxDecoration(border: Border.all(color: Colors.grey, width: 1)),
      child: Scrollbar(
        isAlwaysShown: true,
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
                  BxLoG.d('u enter text: $str');
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}