import 'package:example/database/box_cache_table.dart';
import 'package:example/model/bread.dart';
import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';

/// DB Manager
class BoxDatabaseManager {
  /// 当数据库的表设计有更新, 则更新此版本号
  static int version = 1;

  static bool isInited = false;
  static late BoxerDatabase boxer;

  static Future<void> init() async {
    if (isInited) return;
    isInited = !isInited;

    /// 创建一个数据库实例
    boxer = BoxerDatabase(version: version, name: 'database.db');

    /// 错误处理
    BoxerLogger.onFatalError = (e, s) {
      /// 输出、上报日志/Sentry
    };

    BoxerLogger.logger = (level, tag, message) {
      String prefix = BoxerLogger.levelToString(level);
      print('$prefix/${DateTime.now()}: [$tag] $message');
    };

    /// 注册各个表实例
    boxer.registerTable(BoxTableManager.cacheTableCommon);
    boxer.registerTable(BoxTableManager.cacheTableStudent);

    /// TODO ...
    /// 注册Model与Json的转换器, 用于插入与更新
    BoxerTableTranslator.setModelTranslator<Bread>(
      (e) => Bread.fromJson(e),
      (e) => e.toJson(),
      (e) => {BoxCacheTable.kCOLUMN_ITEM_ID: e.uuid},
    );

    /// 打开并连接数据库
    await boxer.open();

    /// 或者直接设置已打开的 database 对象
    // db.setDatabase(database);
  }
}

/// Table Manager
class BoxTableManager {
  /// 表名私有，业务方通过 BoxCacheTable.tableName 来访问
  static const String _kNAME_BIZ_COMMON = 'cache_table_common';
  static const String _kNAME_BIZ_STUDENTS = 'cache_table_student';

  /// 请在 CacheTableHandler 写好对应的 get 方法来给业务通过 CacheTableHandler 来访问
  static BoxCacheTable cacheTableCommon = BoxCacheTable(tableName: _kNAME_BIZ_COMMON);
  static BoxCacheTable cacheTableStudent = BoxCacheTable(tableName: _kNAME_BIZ_STUDENTS);
}
