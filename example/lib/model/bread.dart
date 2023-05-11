import 'dart:convert';

class Bread {
  final int? breadId;
  final String? uuid;
  final String? breadType;
  String? breadContent;
  String? breadUpdateTime;
  final String? breadCreateTime;
  List<BreadTag> breadTagList;

  Bread.fromJson(Map json)
      : //
        breadId = json['breadId'],
        uuid = json['uuid'],
        breadType = json['breadType'],
        breadContent = json['breadContent'],
        breadUpdateTime = json['breadUpdateTime'],
        breadCreateTime = json['breadCreateTime'],
        breadTagList = List<BreadTag>.from((json['breadTagList'] as List?)?.map((e) => BreadTag.fromJson(e)) ?? []);

  Map<String, dynamic> toJson() => {
        'breadId': breadId,
        'uuid': uuid,
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
