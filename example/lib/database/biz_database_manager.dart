import 'package:example/database/biz_table_cache.dart';
import 'package:example/model/bread.dart';
import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';

/// DB 管理者
class BizDatabaseManager {
  /// 当数据库的表设计有更新, 则更新此版本号
  static int version = 1;

  static bool isInited = false;
  static late BoxerDatabase db;

  static Future<void> init() async {
    if (isInited) return;
    isInited = !isInited;

    /// 创建一个数据库实例
    db = BoxerDatabase(version: version);

    /// 错误处理
    db.onError = (e, s) {
      /// 输出、上报日志/Sentry
    };

    /// 注册各个表实例
    db.registerTable(BizTables.kNAME_ARTICLE_LIST, BizTables.articleListTable);
    db.registerTable(BizTables.kNAME_ARTICLE_TITLE, BizTables.articleTitleTable);
    db.registerTable(BizTables.kNAME_ARTICLE_STATUS, BizTables.articleStatusTable);
    db.registerTable(BizTables.kNAME_FAVORITE_TOOLS, BizTables.favoriteToolsTable);

    /// 打开并连接数据库
    await db.open();

    /// 或者直接设置已打开的 database 对象
    // db.setDatabase(database);

    /// TODO ...
    /// 注册Model与Json的转换器, 用于插入与更新
    BoxerTableCommon.setModelTranslator<Bread>(
      (e) => Bread.fromJson(e),
      (e) => e.toJson(),
      (e) => {BizTableCache.kCOLUMN_ITEM_ID: e.breadUuid},
    );
  }
}

/// Table 管理者
class BizTables {
  static const String kNAME_ARTICLE_LIST = 'cache_article_list'; // 文章列表
  static const String kNAME_ARTICLE_TITLE = 'cache_article_title'; // 文章标题
  static const String kNAME_ARTICLE_STATUS = 'cache_article_status'; // 文章阅读状态，语音文章的播放完毕与否状态
  static const String kNAME_FAVORITE_TOOLS = 'cache_favorite_tools'; // 常用工具

  static BizTableCache articleListTable = BizTableCache(tableName: kNAME_ARTICLE_LIST);
  static BizTableCache articleTitleTable = BizTableCache(tableName: kNAME_ARTICLE_TITLE);
  static BizTableCache articleStatusTable = BizTableCache(tableName: kNAME_ARTICLE_STATUS);
  static BizTableCache favoriteToolsTable = BizTableCache(tableName: kNAME_FAVORITE_TOOLS);
}
