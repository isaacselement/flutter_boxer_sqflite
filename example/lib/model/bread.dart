import 'dart:convert';

import 'dart:math';

import 'package:flutter_dialog_shower/flutter_dialog_shower.dart';

class Bread {
  final int? breadId;
  final String? breadUuid;
  final String? breadType;
  String? breadContent;
  String? breadUpdateTime;
  final String? breadCreateTime;
  List<BreadTag> breadTagList;

  Bread.fromJson(Map json)
      : //
        breadId = json['breadId'],
        breadUuid = json['breadUuid'],
        breadType = json['breadType'],
        breadContent = json['breadContent'],
        breadUpdateTime = json['breadUpdateTime'],
        breadCreateTime = json['breadCreateTime'],
        breadTagList = List<BreadTag>.from((json['breadTagList'] as List?)?.map((e) => BreadTag.fromJson(e)) ?? []);

  Map<String, dynamic> toJson() => {
        'breadId': breadId,
        'breadUuid': breadUuid,
        'breadType': breadType,
        'breadContent': breadContent,
        'breadUpdateTime': breadUpdateTime,
        'breadCreateTime': breadCreateTime,
        'breadTagList': breadTagList.map((e) => e.toJson()).toList(),
      };

  String toString() => json.encode(toJson());
}

class BreadTag {
  final int? tagId;
  final String? tagFlag;
  final String? tagName;

  BreadTag.fromJson(Map json)
      : //
        tagId = json['tagId'],
        tagFlag = json['tagFlag'],
        tagName = json['tagName'];

  Map<String, dynamic> toJson() => {
        'tagFlag': tagFlag,
        'tagName': tagName,
        'tagId': tagId,
      };

  String toString() => json.encode(toJson());
}

class BreadFake {
  static int breadSeq = 0;
  static int breadTagId = 0;

  static Bread get oneModel => Bread.fromJson(oneMap);

  static Map<String, Object?> get oneMap => Map.from(
        {
          "breadId": DateTime.now().millisecondsSinceEpoch,
          "breadUuid": '${breadSeq++}${StringsUtils.fakeUUID()}',
          "breadType": Random().nextBool() ? "voice" : "common",
          "breadContent": "You are so handsome!!!!!",
          "breadUpdateTime": "2023-04-01 00:00:00",
          "breadCreateTime": "2023-03-03 00:00:00",
          "breadTagList": [
            {"tagId": breadTagId++, "tagName": "最新", "tagFlag": "newest"},
            {"tagId": breadTagId++, "tagName": "头条", "tagFlag": "headline"},
            {"tagId": breadTagId++, "tagName": "必读", "tagFlag": "force_read"},
          ],
        },
      );
}
