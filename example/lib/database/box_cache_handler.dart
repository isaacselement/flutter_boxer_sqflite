import 'dart:async';

import 'package:example/database/box_cache_table.dart';
import 'package:example/database/box_database_manager.dart';
import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';

class BoxCacheHandler {
  static BoxCacheTable get commonTable => BoxTableManager.cacheTableCommon;

  static BoxCacheTable get settingsTable => BoxTableManager.cacheTableSettings;

  static BoxCacheTable get studentsTable => BoxTableManager.cacheTableStudents;
}

class BoxCommonTableHandler {
  static BoxCacheTable get table => BoxCacheHandler.commonTable;

  /// Load data from cache table
  static Future<List<Map>> loadDataList(String type) async {
    try {
      BoxerQueryOption op = BoxerQueryOption.e(column: BoxCacheTable.kCOLUMN_ITEM_TYPE, value: type);
      return await table.mQueryAsMap(options: op);
    } catch (e, s) {
      BoxerLogger.d('Biz', 'Load data list error: $e, $s');
    }
    return [];
  }

  /// Update data to cache table
  static Future<void> updateDataList(List<dynamic> list, String? type) async {
    try {
      type = type ?? '';
      BoxerQueryOption op = BoxerQueryOption.e(column: BoxCacheTable.kCOLUMN_ITEM_TYPE, value: type);
      await table.resetWithItems(list, option: op, translator: (dynamic e) {
        Map<String, Object?> values = table.writeTranslator!(e);
        values[BoxCacheTable.kCOLUMN_ITEM_TYPE] = type;
        values[BoxCacheTable.kCOLUMN_ITEM_ID] = e is Map ? e['uuid']?.toString() ?? '' : '';
        return values;
      });
    } catch (e, s) {
      BoxerLogger.d('Biz', 'update data list error: $e, $s');
    }
  }
}
