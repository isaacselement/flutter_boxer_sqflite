import 'package:example/database/box_cache_table.dart';
import 'package:example/model/bread.dart';
import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';

/// DB Manager
class BoxDatabaseManager {
  /// When create a new table/a table struct is updated, update this version number
  static int version = 2;

  static bool isInited = false;
  static late BoxerDatabase boxer;

  static Future<void> init() async {
    if (isInited) return;
    isInited = !isInited;

    /// Initial a `Database` instance that wrapped by the `boxer` instance
    boxer = BoxerDatabase(version: version, name: 'database.db');

    /// Fatal Error handler
    BoxerLogger.onFatalError = (e, s) {
      // Log it or upload to Sentry
    };

    /// Logger
    BoxerLogger.logger = (level, tag, message) {
      String prefix = BoxerLogger.levelToString(level);
      print('$prefix/${DateTime.now()}: [$tag] $message');
    };

    /// Register table instances
    boxer.registerTable(BoxTableManager.cacheTableCommon);
    boxer.registerTable(BoxTableManager.cacheTableTasks);
    boxer.registerTable(BoxTableManager.cacheTableSettings);
    boxer.registerTable(BoxTableManager.cacheTableStudents);

    /// Register the converter of Model and Json for insert/update/query/delete
    BoxerTableTranslator.setModelTranslator<Bread>(
      (e) => Bread.fromJson(e),
      (e) => e.toJson(),
      (e) => {BoxCacheTable.kCOLUMN_ITEM_ID: e.uuid},
    );

    /// Open and connect to database
    await boxer.open();

    /// Or directly set the opened `sqflite database` object
    // db.setDatabase(database);
  }
}

/// Table Manager
class BoxTableManager {
  /// private table names，business can access by BoxCacheTable.tableName
  static const String _kNAME_BIZ_COMMON = 'cache_table_common';
  static const String _kNAME_BIZ_TASKS = 'cache_table_tasks';
  static const String _kNAME_BIZ_SETTINGS = 'cache_table_settings';
  static const String _kNAME_BIZ_STUDENTS = 'cache_table_students';

  /// It's better offer corresponding `get` method in `CacheTableHandler` to access these table instances
  static BoxCacheTable cacheTableCommon = BoxCacheTable(tableName: _kNAME_BIZ_COMMON);
  static BoxCacheTable cacheTableTasks = BoxCacheTable(tableName: _kNAME_BIZ_TASKS);
  static BoxCacheTable cacheTableSettings = BoxCacheTable(tableName: _kNAME_BIZ_SETTINGS);
  static BoxCacheTable cacheTableStudents = BoxCacheTable(tableName: _kNAME_BIZ_STUDENTS);
}
