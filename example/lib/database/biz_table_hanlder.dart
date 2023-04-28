import 'dart:async';

import 'package:example/database/biz_database_manager.dart';
import 'package:example/database/biz_table_cache.dart';
import 'package:example/model/bread.dart';
import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';
import 'package:synchronized_call/synchronized_call.dart';

/// 文章列表 缓存业务逻辑
class BizArticleListHandler {
  static Future<dynamic> getData({
    required Future<dynamic> cacheFuture,
    required Future<dynamic> requestFuture,
    required void Function(dynamic value) updateCache,
    required void Function(dynamic result) updateView,
    void Function(Future<dynamic> future, dynamic error, dynamic stackTrace)? onError,
  }) async {
    bool isRequestDone = false;
    Completer<dynamic> completer = Completer();
    cacheFuture.then((value) {
      /// No need the cache data cause request data return first
      if (isRequestDone) return;

      /// Update UI
      updateView(value);
    }).onError((error, stackTrace) {
      onError?.call(cacheFuture, error, stackTrace);
    });
    requestFuture.then((value) async {
      isRequestDone = true;
      completer.complete(value);

      /// Update UI
      updateView(value);

      /// Update to local db cache
      updateCache(value);
    }).onError((error, stackTrace) {
      onError?.call(cacheFuture, error, stackTrace);
    });
    return completer.future;
  }
}

class BizTableArticleList {
  /// 获取 文章列表 本地缓存
  static Future<List<Bread>> getArticleList(String flag) async {
    try {
      String type = flag;
      BoxerQueryOption op = BoxerQueryOption.e(column: BizTableCache.kCOLUMN_TYPE, value: type);
      List<Bread> articles = await BizTables.articleListTable.mQueryAsModels<Bread>(fromJson: (e) => Bread.fromJson(e), options: op);
      return articles;
    } catch (e, s) {
      BxLoG.d('get article list error: $e, $s');
    }
    return [];
  }

  /// 更新 文章列表 本地缓存
  static Future<void> updateArticleList(List<dynamic> articlesJson, String? flag) async {
    try {
      String type = flag ?? '';
      BoxerQueryOption op = BoxerQueryOption.e(column: BizTableCache.kCOLUMN_TYPE, value: type);
      await BizTables.articleListTable.resetWithItems(articlesJson, option: op, translator: (dynamic e) {
        Map<String, Object?> values = BizTables.articleListTable.insertionTranslator!(e);
        values[BizTableCache.kCOLUMN_ITEM_ID] = e is Map ? e['uuid']?.toString() ?? '' : '';
        return values;
      });
    } catch (e, s) {
      BxLoG.d('update article list error: $e, $s');
    }
  }
}

/// 文章标题 缓存业务逻辑
class BizTableArticleTitle {
  // 获取
  static Future<List<Map>> getArticleTitles() async {
    return await BizTables.articleTitleTable.mQueryAsMap();
  }

  // 更新
  static Future<void> updateArticleTitles(List<dynamic> list) async {
    await BizTables.articleTitleTable.resetWithItems(list);
  }
}

/// 文章已读状态 缓存业务逻辑
class BizTableArticleStatus {
  /// Article read/play status
  static const String kREAD_VALUE = '1';
  static const String kTYPE_VOICE_PLAY_DONE = 'voice_play_done';

  /// 判断文章是否已读
  static Future<bool> isArticleRead(String articleUUID) async {
    try {
      String? read = await BizTables.articleStatusTable.getOne(itemId: articleUUID);
      return read == kREAD_VALUE;
    } catch (e, s) {
      BxLoG.d('check article read status error: $e, $s');
    }
    return false;
  }

  /// 标志文章已读
  static Future<void> markArticleAsRead(String articleUUID) async {
    try {
      if (await isArticleRead(articleUUID)) return;

      /// 如果表的记录数超过某个数量，清除掉一些旧的
      int? count = await BizTables.articleStatusTable.selectCount();
      if (count != null && count > 200) {
        int? maxId = await BizTables.articleStatusTable.maxId();
        if (maxId != null) {
          int lessThan = maxId - count ~/ 2;
          BoxerQueryOption op1 = BoxerQueryOption.l(column: BizTableCache.kCOLUMN_ID, value: lessThan);
          BoxerQueryOption op2 = BoxerQueryOption.isNull(column: BizTableCache.kCOLUMN_TYPE);
          BoxerQueryOption ops = BoxerQueryOption.merge([op1, op2]);
          int deleted = await BizTables.articleStatusTable.delete(where: ops.where, whereArgs: ops.whereArgs);
          BxLoG.d('markArticleAsRead, delete count: $deleted');
        }
      }

      /// 记录已读
      await BizTables.articleStatusTable.addOne(value: kREAD_VALUE, itemId: articleUUID);
    } catch (e, s) {
      BxLoG.d('markArticleAsRead error: $e, $s');
    }
  }

  /// 判断音频文章是否已经播放完毕
  static Future<bool> isArticleVoiceFullyPlayed(String? articleUUID) async {
    if (articleUUID == null) return false;
    try {
      String? read = await BizTables.articleStatusTable.getOne(itemId: articleUUID, type: kTYPE_VOICE_PLAY_DONE);
      return read == kREAD_VALUE;
    } catch (e, s) {
      BxLoG.d('isArticleVoiceFullyPlayed error: $e, $s');
    }
    return false;
  }

  /// 标志音频文章已经播放完毕
  static Future<void> markArticleVoiceFullyPlayed(String? articleUUID) async {
    if (articleUUID == null) return;
    CallLock.get("__voice_fully_played__").call(() async {
      try {
        /// 记录已播放完毕
        if (await isArticleVoiceFullyPlayed(articleUUID)) return;
        BoxerQueryOption op1 = BoxerQueryOption.e(column: BizTableCache.kCOLUMN_TYPE, value: kTYPE_VOICE_PLAY_DONE);
        int? count = await BizTables.articleStatusTable.count(op1);
        if (count != null && count > 100) {
          await BizTables.articleStatusTable.clear(op1);
        }
        await BizTables.articleStatusTable.addOne(value: kREAD_VALUE, itemId: articleUUID, type: kTYPE_VOICE_PLAY_DONE);
      } catch (e, s) {
        BxLoG.d('markArticleVoiceFullyPlayed error: $e, $s');
      }
    });
  }
}

/// 快捷工具/常用工具 缓存业务逻辑
class BizTableFavoriteTool {
  /// Quick entrance / Favorite tools, business logic.

  // 获取
  static Future<List<Map>> getFavoriteTools() async {
    return await BizTables.favoriteToolsTable.mQueryAsMap();
  }

  // 更新
  static Future<void> updateFavoriteTools(List<dynamic> list) async {
    await BizTables.favoriteToolsTable.resetWithItems(list);
  }
}
