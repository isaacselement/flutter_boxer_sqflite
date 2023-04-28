import 'dart:async';

import 'package:sqflite/sqflite.dart';
import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';

class BoxerDatabase {
  BoxerDatabase({required this.version, this.path, this.name});

  /// Database version. IMPORTANT!!! Changing it will affect the database opening phase's callback functions
  final int version;

  /// Database file's path
  String? path;

  /// Database file's name
  String? name;

  /// Database instance of sqflite
  late Database database;

  void setDatabase(Database db) {
    database = db;
    tables.forEach((entry) {
      entry.boxer = this;
      entry.database = db;
    });
  }

  /// Database operations error handler, execute or query sql etc...
  BoxerDatabaseError? onError;

  void reportError(dynamic e, dynamic s) => onError?.call(e, s);

  /// Create and open database
  Future<void> open() async {
    name ??= 'database.db';
    path ??= '${await getDatabasesPath()}/$name';
    if (path?.endsWith('/') ?? false) {
      path = '$path$name';
    }
    String dbPath = path!;
    assert(() {
      print('[BoxerDatabase] - opening database, local path is: $dbPath');
      return true;
    }());

    /// will sync call onConfigure/onCreate/onUpgrade/onDowngrade/onOpen if needed
    await openDB(path: dbPath, version: version);
    assert(() {
      print('[BoxerDatabase] - open database done');
      return true;
    }());
  }

  Future<Database> openDB({required String path, int? version}) async {
    return await openDatabase(
      path,
      version: version,
      onConfigure: _onConfigureDB,
      onCreate: _onCreateDB,
      onUpgrade: _onUpgradeDB,
      onDowngrade: _onDowngradeDB,
      onOpen: _onOpenDB,
    );
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

  T? getTable<T extends BoxerTableBase>(String name) => namedTables[name] as T?;

  void registerTable(String name, BoxerTableBase table) => namedTables[name] = table;

  List<BoxerTableBase> get tables => namedTables.entries.map((e) => e.value).toList();

  T? ofTable<T extends BoxerTableBase>() => tables.map((e) => e is T).toList().firstSafe as T?;

  /**
   * Utilities of SQL operation (select/insert/update/delete)
   */

  /// Check if current table created success using 'sqlite_master'
  Future<bool> isTableExisted(String tableName) async {
    return await DatabaseUtil.isTableExistedRaw(database, tableName);
  }

  /// Select count
  Future<int?> selectCount(String tableName, {String? where, List<Object?>? whereArgs}) async {
    return await DatabaseUtil.selectCountRaw(database, tableName, where: where, whereArgs: whereArgs);
  }

  /// Select Max of column value
  Future<Object?> selectMax(String tableName, String column) async {
    return await DatabaseUtil.selectMaxRaw(database, tableName, column);
  }

  /// Select Min of column value
  Future<Object?> selectMin(String tableName, String column) async {
    return await DatabaseUtil.selectMinRaw(database, tableName, column);
  }

  /// Drop table
  Future<bool> dropTable(String tableName) async {
    return await DatabaseUtil.dropTableRaw(database, tableName);
  }

  /// Reset auto increment ID
  Future<void> resetAutoId(String tableName) async {
    await DatabaseUtil.resetAutoIdRaw(database, tableName: tableName);
  }

  /// Iterate all the tables
  Future<void> iterateAllTables(FutureOr<bool?> Function(String tableName, List<String> columns) iterator) async {
    return await DatabaseUtil.iterateAllTablesRaw(database, iterator);
  }

  /// Get table (except sqlite_master) column names
  Future<List<String>> getTableColumnNames(String tableName) => DatabaseUtil.getTableColumnNamesRaw(database, tableName);
}

typedef BoxerDatabaseError = void Function(/* Object */ dynamic exception, /* StackTrace? */ dynamic stack);
