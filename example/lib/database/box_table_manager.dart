import 'package:example/database/box_table_cache.dart';

/// Table 管理者
class BoxTableManager {
  static const String kNAME_ARTICLE_LIST = 'cache_article_list';      // 文章列表
  static const String kNAME_ARTICLE_TITLE = 'cache_article_title';    // 文章标题
  static const String kNAME_ARTICLE_STATUS = 'cache_article_status';  // 文章阅读状态，语音文章的播放完毕与否状态
  static const String kNAME_FAVORITE_TOOLS = 'cache_favorite_tools';  // 常用工具

  static BoxTableCache articleListTable = BoxTableCache(tableName: kNAME_ARTICLE_LIST);
  static BoxTableCache articleTitleTable = BoxTableCache(tableName: kNAME_ARTICLE_TITLE);
  static BoxTableCache articleStatusTable = BoxTableCache(tableName: kNAME_ARTICLE_STATUS);
  static BoxTableCache favoriteToolsTable = BoxTableCache(tableName: kNAME_FAVORITE_TOOLS);
}
