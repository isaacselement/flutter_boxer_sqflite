import 'package:example/database/box_cache_table.dart';
import 'package:example/database/box_cache_tasks.dart';
import 'package:example/database/box_tasks_manager.dart';
import 'package:example/model/bread.dart';
import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';

/// DB Manager
class BoxDatabaseManager {
  /// When create a new table/a table struct is updated, update this version number
  static int version = 2;

  static String name = 'database.db';

  static bool isInited = false;
  static late BoxerDatabase boxer;

  static Future<void> init() async {
    try {
      return await _init();
    } catch (e, s) {
      print('🚫INIT🚫: $e, $s');
    }
  }

  static Future<void> _init() async {
    if (isInited) return;
    isInited = !isInited;

    /// Initial a `Database` instance that wrapped by the `boxer` instance
    boxer = BoxerDatabase(version: version, name: name);

    /// Fatal Error handler
    BoxerLogger.fatalReporter = (e, s) {
      // Log it or upload to Sentry
    };

    /// Logger
    BoxerLogger.logger = (level, tag, message) {
      bool isError = level >= 4; // error & fatal log
      print('${BoxerLogger.levelMap[level]}/${DateTime.now()}: [$tag] ${isError ? '‼️‼️' : ''}$message');
    };

    /// Marker
    BoxerLogger.marker = (flag, tag, data) {
      print('♻️MARK♻️: $flag, $tag, $data');
    };

    /// Register table instances
    boxer.registerTable(BoxTableManager.cacheTableCommon);
    boxer.registerTable(BoxTableManager.cacheTableSettings);
    boxer.registerTable(BoxTableManager.cacheTableStudents);
    boxer.registerTable(BoxTableManager.cacheTableTasks);

    /// Register the converter of Model and Json for insert/update/query/delete
    BoxerModelTranslator.setModelTranslator<Bread>(
      (e) => Bread.fromJson(e),
      (e) => e.toJson(),
      (e) => {BoxCacheTable.kCOLUMN_ITEM_ID: e.uuid},
    );

    /// Open and connect to database
    await boxer.open();

    /// Or directly set the opened `sqflite database` object
    // db.setDatabase(database);

    /// Init the cache task manager
    BoxTasksManager.init();
  }
}

/// Table Manager
class BoxTableManager {
  /// private table names，business can access by BoxCacheTable.tableName
  static const String _kNAME_BIZ_COMMON = 'cache_table_common';
  static const String _kNAME_BIZ_SETTINGS = 'cache_table_settings';
  static const String _kNAME_BIZ_STUDENTS = 'cache_table_students';
  static const String _kNAME_BIZ_TASKS = 'cache_table_tasks';

  /// It's better offer corresponding `get` method in `CacheTableHandler` to access these table instances
  static BoxCacheTable cacheTableCommon = BoxCacheTable(tableName: _kNAME_BIZ_COMMON);
  static BoxCacheTable cacheTableSettings = BoxCacheTable(tableName: _kNAME_BIZ_SETTINGS);
  static BoxCacheTable cacheTableStudents = BoxCacheTable(tableName: _kNAME_BIZ_STUDENTS);
  static BoxCacheTable cacheTableTasks = BoxCacheTaskTable(tableName: _kNAME_BIZ_TASKS);
}
