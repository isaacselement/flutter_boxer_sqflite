import 'package:example/database/biz_table_cache.dart';
import 'package:example/database/biz_table_manager.dart';
import 'package:example/model/bread.dart';
import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';

/// DB 管理者
class BizDatabaseManager {
  /// 当数据库的表设计有更新, 则更新此版本号
  static int version = 1;

  static bool isInited = false;
  static late BoxerDatabase boxer;

  static Future<void> init() async {
    if (isInited) return;
    isInited = !isInited;

    /// 创建一个数据库实例
    boxer = BoxerDatabase(version: version);

    /// 错误处理
    boxer.onError = (e, s) {
      /// 输出、上报日志/Sentry
    };

    /// 注册各个表实例
    boxer.registerTable(BizTableManager.articleListTable);
    boxer.registerTable(BizTableManager.articleTitleTable);
    boxer.registerTable(BizTableManager.articleStatusTable);
    boxer.registerTable(BizTableManager.favoriteToolsTable);

    /// 打开并连接数据库
    await boxer.open();

    /// 或者直接设置已打开的 database 对象
    // db.setDatabase(database);

    /// TODO ...
    /// 注册Model与Json的转换器, 用于插入与更新
    BoxerTableTranslator.setModelTranslator<Bread>(
      (e) => Bread.fromJson(e),
      (e) => e.toJson(),
      (e) => {BizTableCache.kCOLUMN_ITEM_ID: e.uuid},
    );
  }
}
