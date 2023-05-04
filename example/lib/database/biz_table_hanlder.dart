import 'dart:async';

import 'package:example/database/biz_table_cache.dart';
import 'package:example/database/biz_table_manager.dart';
import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';
import 'package:synchronized_call/synchronized_call.dart';

/// 缓存业务逻辑
class SqlCacheHandler {
  /// cacheFuture 与 requestFuture 完成后都会调 updateView
  ///
  /// requestFuture 比 cacheFuture 先完成，那么 cacheFuture 的数据不会去 updateView
  ///
  /// requestFuture 完成后会调 updateCache 去更新缓存表
  static Future<T> getData<T>({
    required Future<T> cacheFuture,
    required Future<T> requestFuture,
    required void Function(T value) updateCache,
    required void Function(T result, bool isFromCache) updateView,
    void Function(bool isCache, dynamic error, dynamic stackTrace)? onError,
  }) async {
    bool isRequestDone = false;
    Completer<T> completer = Completer();
    cacheFuture.then((value) {
      /// No need the cache data cause request data return first
      if (isRequestDone) return;

      /// Update UI
      updateView(value, true);
    }).onError((error, stackTrace) {
      onError?.call(true, error, stackTrace);
    });
    requestFuture.then((value) async {
      isRequestDone = true;
      completer.complete(value);

      /// Update UI
      updateView(value, false);

      /// Update to local db cache
      updateCache(value);
    }).onError((error, stackTrace) {
      onError?.call(false, error, stackTrace);
    });
    return completer.future;
  }
}

class BizTableArticleList {
  /// 获取 文章列表 本地缓存
  static Future<List<Map>> getArticleList(String flag) async {
    try {
      String type = flag;
      BoxerQueryOption op = BoxerQueryOption.e(column: BizTableCache.kCOLUMN_TYPE, value: type);
      List<Map> articles = await BizTableManager.articleListTable.mQueryAsMap(options: op);
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
      await BizTableManager.articleListTable.resetWithItems(articlesJson, option: op, translator: (dynamic e) {
        Map<String, Object?> values = BizTableManager.articleListTable.insertionTranslator!(e);
        values[BizTableCache.kCOLUMN_TYPE] = type;
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
    return await BizTableManager.articleTitleTable.mQueryAsMap();
  }

  // 更新
  static Future<void> updateArticleTitles(List<dynamic> list) async {
    await BizTableManager.articleTitleTable.resetWithItems(list);
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
      String? read = await BizTableManager.articleStatusTable.getOne(itemId: articleUUID);
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
      int? count = await BizTableManager.articleStatusTable.selectCount();
      if (count != null && count > 200) {
        int? maxId = await BizTableManager.articleStatusTable.maxId();
        if (maxId != null) {
          int lessThan = maxId - count ~/ 2;
          BoxerQueryOption op1 = BoxerQueryOption.l(column: BizTableCache.kCOLUMN_ID, value: lessThan);
          BoxerQueryOption op2 = BoxerQueryOption.isNull(column: BizTableCache.kCOLUMN_TYPE);
          BoxerQueryOption ops = BoxerQueryOption.merge([op1, op2]);
          int deleted = await BizTableManager.articleStatusTable.delete(where: ops.where, whereArgs: ops.whereArgs);
          BxLoG.d('markArticleAsRead, delete count: $deleted');
        }
      }

      /// 记录已读
      await BizTableManager.articleStatusTable.addOne(value: kREAD_VALUE, itemId: articleUUID);
    } catch (e, s) {
      BxLoG.d('markArticleAsRead error: $e, $s');
    }
  }

  /// 判断音频文章是否已经播放完毕
  static Future<bool> isArticleVoiceFullyPlayed(String? articleUUID) async {
    if (articleUUID == null) return false;
    try {
      String? read = await BizTableManager.articleStatusTable.getOne(itemId: articleUUID, type: kTYPE_VOICE_PLAY_DONE);
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
        int? count = await BizTableManager.articleStatusTable.count(op1);
        if (count != null && count > 100) {
          await BizTableManager.articleStatusTable.clear(op1);
        }
        await BizTableManager.articleStatusTable.addOne(value: kREAD_VALUE, itemId: articleUUID, type: kTYPE_VOICE_PLAY_DONE);
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
    return await BizTableManager.favoriteToolsTable.mQueryAsMap();
  }

  // 更新
  static Future<void> updateFavoriteTools(List<dynamic> list) async {
    await BizTableManager.favoriteToolsTable.resetWithItems(list);
  }
}
