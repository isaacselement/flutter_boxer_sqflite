import 'dart:async';

import 'package:example/database/box_cache_table.dart';
import 'package:example/database/box_database_manager.dart';
import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';

class BoxCacheHandler {
  static BoxCacheTable get commonTable => BoxTableManager.cacheTableCommon;

  static BoxCacheTable get cacheTableTasks => BoxTableManager.cacheTableTasks;

  static BoxCacheTable get settingsTable => BoxTableManager.cacheTableSettings;

  static BoxCacheTable get studentsTable => BoxTableManager.cacheTableStudents;
}

class BoxTableHandler {
  BoxTableHandler({required this.table});

  late BoxCacheTable table;

  /// Load data from cache table
  Future<List<Map>> loadDataList({required String type}) async {
    try {
      BoxerQueryOption op = BoxerQueryOption.e(column: BoxCacheTable.kCOLUMN_ITEM_TYPE, value: type);
      return await table.mQueryAsMap(options: op);
    } catch (e, s) {
      BoxerLogger.d('Biz', 'Load data list error: $e, $s');
    }
    return [];
  }

  /// Update data to cache table
  Future<void> updateDataList(List<dynamic> list, {String type = ''}) async {
    try {
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
