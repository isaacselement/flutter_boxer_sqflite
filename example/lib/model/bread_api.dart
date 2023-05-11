import 'dart:math';

import 'package:example/common/util/dates_utils.dart';
import 'package:example/model/bread.dart';
import 'package:flutter_dialog_shower/flutter_dialog_shower.dart';

class BreadApi {
  static Future<List<Map>> getList() async {
    String date = DatesUtils.format(DateTime.now(), pattern: 'HH:mm:ss');
    return [for (int i = 0; i < 10; i++) BreadGenerator.oneMap(content: 'From API $date', createTime: DateTime.now())];
  }

  static Future<List<Bread>> getListAsModel({Duration? duration}) async {
    return (await getListAsModel(duration: duration)).map((e) => Bread.fromJson(e as Map)).toList();
  }
}

class BreadGenerator {
  static int breadSeq = 0;
  static int breadTagId = 0;

  static Bread get oneModel => Bread.fromJson(oneMap());

  static Map<String, Object?> oneMap({
    String? content,
    DateTime? updateTime,
    DateTime? createTime,
  }) {
    return Map.from(
      {
        "breadId": DateTime.now().millisecondsSinceEpoch,
        "uuid": '${breadSeq++}${StringsUtils.fakeUUID()}',
        "breadType": Random().nextBool() ? "Cold" : "Hot",
        "breadContent": content ?? "You are so handsome!!!!!",
        "breadUpdateTime": updateTime != null ? DatesUtils.format(updateTime) : "2023-04-04 00:00:00",
        "breadCreateTime": createTime != null ? DatesUtils.format(createTime) : "2023-03-03 00:00:00",
        "breadTagList": [
          {"tagId": breadTagId++, "tagName": "New", "tagFlag": "Newest"},
          {"tagId": breadTagId++, "tagName": "Top", "tagFlag": "Headline"},
          {"tagId": breadTagId++, "tagName": "Must-Read", "tagFlag": "Worthy"},
        ],
      },
    );
  }
}
