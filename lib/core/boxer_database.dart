import 'dart:async';
import 'dart:io';

import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';

class BoxerDatabase {
  BoxerDatabase({required this.version, this.path, this.name});

  /// Database version
  /// IMPORTANT!!! Changing it will affect the database opening phase's callback functions
  final int version;

  /// Database file's path
  String? path;

  /// Database file's name
  String? name;

  /// Database instance of sqflite
  Database? _database;

  Database get database {
    assert(_database != null, "❗️❗️❗️FATAL!!! You should open database first");
    return _database!;
  }

  void setDatabase(Database db) {
    _database = db;
    tables.forEach((table) {
      table.database = _database!;
    });
  }

  /// Create and Open Database instance
  /// Set [_database] and [openingCompleter] to null if u want to re-open database
  Completer<Database?>? openingCompleter;

  FutureOr<Database?> open() async {
    if (_database != null) {
      return _database;
    }
    if (openingCompleter != null) {
      return await openingCompleter!.future;
    }
    openingCompleter = Completer();
    Database? db;
    try {
      name ??= "database.db";

      /// For windows & linux
      if (Platform.isWindows || Platform.isLinux) {
        // example/.dart_tool/sqflite_common_ffi/databases/~/Downloads/database.db
        path ??= "~/Downloads/";
      }

      path ??= "${await getDatabasesPath()}/$name";
      if (path?.endsWith("/") ?? false) {
        path = "$path$name";
      }
      String dbPath = path!;
      BoxerLogger.i(null, "[BoxerDatabase] - opening database, local path is: $dbPath");
      assert(() {
        () async {
          File file = File(dbPath);
          FileStat stat = await file.stat();
          print('DB file absolute path is: ${file.absolute.path}');
          print('DB file mode: ${stat.mode.toRadixString(16)}, ${stat.modeString()}');
        }();
        return true;
      }());

      /// will sync call onConfigure -> onCreate -> onUpgrade -> onDowngrade -> onOpen if needed
      db = await openDB(path: dbPath, version: version);
      setDatabase(db);
      openingCompleter?.complete(db);
      BoxerLogger.i(null, "[BoxerDatabase] - open database done");
    } catch (e, s) {
      openingCompleter?.complete(null);
      BoxerLogger.f(null, "[BoxerDatabase] - open database error: $e, $s");
      BoxerLogger.reportFatal(e, s);
    }
    // so far, the same instance of properties [_database]
    return db;
  }

  FutureOr<Database> ensureDatabaseAvailable() async {
    if (_database == null && openingCompleter != null) {
      await openingCompleter!.future;
    }
    assert(_database != null, "❗️❗️❗️FATAL!!! You database not call `open` or open failed");
    return _database!;
  }

  Future<Database> openDB({required String path, int? version}) async {
    OpenDatabaseOptions options = OpenDatabaseOptions(
      version: version,
      onConfigure: _onConfigureDB,
      onCreate: _onCreateDB,
      onUpgrade: _onUpgradeDB,
      onDowngrade: _onDowngradeDB,
      onOpen: _onOpenDB,
      readOnly: false,
      singleInstance: true,
    );

    /// For windows & linux
    if (Platform.isWindows || Platform.isLinux) {
      // sqfliteFfiInit();
      // return await databaseFactoryFfi.openDatabase(path, options: options);
    }

    /// For iOS & Android & MacOS
    return await databaseFactory.openDatabase(path, options: options);
  }

  /// Close database, release connection resource
  Future<void> close() async {
    await database.close();
  }

  /// Delete database
  Future<void> delete() async {
    await close();
    await deleteDatabase(database.path);
  }

  /**
   * Database opening phases
   */

  /// Will invoke before open
  Future<void> _onConfigureDB(Database db) {
    setDatabase(db);
    return Future.wait(tables.map((entry) => entry.onConfigure(db)));
  }

  /// Will invoke before open if database file not existed
  Future<void> _onCreateDB(Database db, int version) {
    return Future.wait(tables.map((entry) => entry.onCreate(db, version)));
  }

  /// Will invoke when database version changed to value that less than last version
  Future<void> _onUpgradeDB(Database db, int oldVersion, int newVersion) {
    return Future.wait(tables.map((entry) => entry.onUpgrade(db, oldVersion, newVersion)));
  }

  /// Will invoke when database version changed to value that larger than last version
  Future<void> _onDowngradeDB(Database db, int oldVersion, int newVersion) {
    return Future.wait(tables.map((entry) => entry.onDowngrade(db, oldVersion, newVersion)));
  }

  /// Will invoke after when all (if any) above callback done
  Future<void> _onOpenDB(Database db) {
    return Future.wait(tables.map((entry) => entry.onOpen(db)));
  }

  /**
   * Table instance getter & setter
   */

  /// Register tables for this instance of database
  Map<String, BoxerTableBase> namedTables = {};

  List<BoxerTableBase> get tables => namedTables.entries.map((e) => e.value).toList();

  void registerTable(BoxerTableBase table, {String? name}) {
    namedTables[name ?? table.tableName] = table;
    if (_database != null) {
      table.database = _database!;
    }
  }

  T? getTable<T extends BoxerTableBase>(String name) => namedTables[name] as T?;

  T? ofTable<T extends BoxerTableBase>() => tables.map((e) => e is T).toList().firstSafe as T?;

  /**
   * Utilities of SQL operation (select/insert/update/delete)
   */

  /// Check if current table created success using "sqlite_master"
  Future<bool> isTableExisted(String tableName) async {
    return await BoxerDatabaseUtil.isTableExisted(database, tableName);
  }

  /// Reset auto increment ID
  Future<void> resetAutoId(String tableName) async {
    await BoxerDatabaseUtil.resetAutoId(database, tableName: tableName);
  }

  /// Select count
  Future<int?> selectCount(String tableName, {String? where, List<Object?>? whereArgs}) async {
    return await BoxerDatabaseUtil.selectCount(database, tableName, where: where, whereArgs: whereArgs);
  }

  /// Drop table
  Future<bool> dropTable(String tableName) async {
    return await BoxerDatabaseUtil.dropTable(database, tableName);
  }

  /// Iterate all the tables
  Future<void> iterateAllTables(FutureOr<bool?> Function(String tableName, List<String> columns) iterator) async {
    return await BoxerDatabaseUtil.iterateAllTables(database, iterator);
  }

  /// Get table (except sqlite_master) column names
  Future<List<String>> getColumnNames(String tableName) => BoxerDatabaseUtil.getColumnNames(database, tableName);
}
