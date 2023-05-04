import 'package:example/common/util/date_util.dart';
import 'package:example/model/bread.dart';

class BreadApi {
  static Future<List<Map>> getList({Duration? duration}) async {
    String date = DateUtil.format(DateTime.now(), pattern: 'HH:mm:ss');
    await Future.delayed(duration ?? const Duration(milliseconds: 3000));
    return [for (int i = 0; i < 10; i++) BreadFake.oneMap(content: 'From API $date', createTime: DateTime.now())];
  }

  static Future<List<Bread>> getListAsModel({Duration? duration}) async {
    return (await getListAsModel(duration: duration)).map((e) => Bread.fromJson(e as Map)).toList();
  }
}
