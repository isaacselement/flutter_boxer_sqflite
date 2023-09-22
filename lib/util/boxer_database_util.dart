import 'dart:async';

import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';

class BoxerDatabaseUtil {
  /// Check if current table created success using "sqlite_master"
  static Future<bool> isTableExisted(DatabaseExecutor db, String tableName) async {
    // SELECT count(1) FROM sqlite_master WHERE type="table" AND name = "$tableName";
    int? value =
        await selectCount(db, "sqlite_master", where: "WHERE type= ? AND name = ? ", whereArgs: ["table", tableName]);
    return value != null && value > 0;
  }

  /// Reset auto increment ID. It may not working before u clear your table.
  static Future<void> resetAutoId(DatabaseExecutor db, {String? tableName}) async {
    String sql = "UPDATE sqlite_sequence SET seq = 0 ${tableName != null ? " WHERE name = '$tableName'" : ""}";
    await db.execute(sql);
  }

  /// Select count
  static Future<int?> selectCount(DatabaseExecutor db, String tableName,
      {String? where, List<Object?>? whereArgs}) async {
    Object? value = await select(db, tableName, ["count(1)"], where: where, whereArgs: whereArgs, isUnique: true);
    return value is int ? value : null;
  }

  /// Select Max of column value
  static Future<Object?> selectMax(DatabaseExecutor db, String tableName, String column,
      {String? where, List<Object?>? whereArgs}) async {
    return await select(db, tableName, ["MAX($column)"], where: where, whereArgs: whereArgs, isUnique: true);
  }

  /// Select Min of column value
  static Future<Object?> selectMin(DatabaseExecutor db, String tableName, String column,
      {String? where, List<Object?>? whereArgs}) async {
    return await select(db, tableName, ["MIN($column)"], where: where, whereArgs: whereArgs, isUnique: true);
  }

  /// TODO ... [select] need to completely support all the following parameters:
  // distinct
  // columns
  // where
  // whereArgs
  // groupBy
  // having
  // orderBy
  // limit
  // offset
  /// Select using the assembled SQL, return List<Map<String, Object?>> or Map<String, Object?> or Object?
  static Future<Object?> select(DatabaseExecutor db, String tableName, List<String> columns,
      {String? where, List<Object?>? whereArgs, bool isUnique = false}) async {
    // ignore: non_constant_identifier_names
    String __SEPARATOR__ = ", ";
    String fields = columns.join(__SEPARATOR__);
    if (fields.isEmpty) fields = "*";

    String sql = "SELECT $fields FROM $tableName";
    /// Assemble where clause
    if (where != null && (where = where.trim()).isNotEmpty) {
      if (!where.startsWith("WHERE")) where = "WHERE " + where;
      sql = sql + " " + where;
    }
    /// Execute the sql
    List<Map<String, Object?>> result = await db.rawQuery(sql, whereArgs);
    /// If just want only one field value
    if (isUnique) {
      /// return T is Map<String, Object?> or Object?
      return fields.contains(__SEPARATOR__) ? result.firstSafe : result.firstSafe?.values.firstSafe;
    } else {
      /// return T is List<Map<String, Object?>>
      return result;
    }
  }

  /// Get table (except sqlite_master) column names
  static Future<List<String>> getColumnNames(DatabaseExecutor db, String tableName) async {
    List<String> result = [];
    await iterateAllTables(db, (name, columns) {
      if (name == tableName) {
        result = columns; // it's ok, dart pass the ptr. also clear & addAll or setAll .
        return true;
      }
      return false;
    });
    return result;
  }

  /// Drop table
  static Future<bool> dropTable(DatabaseExecutor db, String tableName) async {
    String sql = "DROP TABLE $tableName";
    await db.execute(sql);
    return !await isTableExisted(db, tableName);
  }

  /// Iterate all the tables
  static Future<void> iterateAllTables(
    DatabaseExecutor db,
    FutureOr<bool?> Function(String tableName, List<String> columns) iterator,
  ) async {
    // for query index, SELECT * FROM sqlite_master WHERE type = "index";
    List<Map<String, Object?>> tables = await db.rawQuery("SELECT * FROM sqlite_master WHERE type='table'");
    for (int i = 0; i < tables.length; i++) {
      Map<String, Object?> element = tables[i];

      /// sqlite> .header on. type, name, tbl_name, rootpage, sql
      String tableName = element["name"].toString();
      String createSQL = element["sql"].toString();
      String? columnSpec = RegExp("\\((.*?)\\)").allMatches(createSQL).first.group(1);

      /// Column names for table
      List<String> columns = [];
      columnSpec?.split(",").forEach((e) {
        String? columnName = e.trim().split(" ").firstSafe;
        if (columnName != null) {
          columns.add(columnName);
        }
      });
      if (await iterator(tableName, columns) == true) break;
    }
  }
}
