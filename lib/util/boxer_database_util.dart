import 'dart:async';

import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';

class BoxerDatabaseUtil {
  /// Check if current table created success using 'sqlite_master'
  static Future<bool> isTableExistedRaw(DatabaseExecutor db, String tableName) async {
    // SELECT count(1) FROM sqlite_master WHERE type="table" AND name = "$tableName";
    int? value = await selectCountRaw(db, 'sqlite_master',
        where: "WHERE type= ? AND name = ? ", whereArgs: ['table', tableName]);
    return value != null && value > 0;
  }

  /// Select count
  static Future<int?> selectCountRaw(DatabaseExecutor db, String tableName,
      {String? where, List<Object?>? whereArgs}) async {
    String sql = "SELECT count(1) FROM $tableName";
    if (where != null && (where = where.trim()).isNotEmpty) {
      if (!where.startsWith('WHERE')) where = "WHERE " + where;
      sql = sql + " " + where;
    }
    List<Map<String, Object?>> result = await db.rawQuery(sql, whereArgs);
    // Object? object = result.firstSafe?["count(1)"];
    // return object is int ? object : null;
    dynamic value = result.firstSafe?.values.firstSafe;
    return value is int ? value : null;
  }

  /// Select Max of column value
  static Future<Object?> selectMaxRaw(DatabaseExecutor db, String tableName, String column) async {
    String sql = "SELECT MAX($column) FROM $tableName";
    List<Map<String, Object?>> result = await db.rawQuery(sql);
    Object? value = result.firstSafe?.values.firstSafe;
    return value;
  }

  /// Select Min of column value
  static Future<Object?> selectMinRaw(DatabaseExecutor db, String tableName, String column) async {
    String sql = "SELECT MIN($column) FROM $tableName";
    List<Map<String, Object?>> result = await db.rawQuery(sql);
    Object? value = result.firstSafe?.values.firstSafe;
    return value;
  }

  /// Drop table
  static Future<bool> dropTableRaw(DatabaseExecutor db, String tableName) async {
    String sql = "DROP TABLE $tableName";
    await db.execute(sql);
    return !await isTableExistedRaw(db, tableName);
  }

  /// Reset auto increment ID. It may not working before u clear your table.
  static Future<void> resetAutoIdRaw(DatabaseExecutor db, {String? tableName}) async {
    try {
      String sql = "UPDATE sqlite_sequence SET seq = 0 ${tableName != null ? " WHERE name = '$tableName'" : ""}";
      await db.execute(sql);
    } catch (e, s) {
      BoxerLogger.e(null, 'Reset auto increment ID error: $e, $s');
    }
  }

  /// Iterate all the tables
  static Future<void> iterateAllTablesRaw(
    DatabaseExecutor db,
    FutureOr<bool?> Function(String tableName, List<String> columns) iterator,
  ) async {
    // for query index, SELECT * FROM sqlite_master WHERE type = 'index';
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

  /// Get table (except sqlite_master) column names
  static Future<List<String>> getTableColumnNamesRaw(DatabaseExecutor db, String tableName) async {
    List<String> result = [];
    await iterateAllTablesRaw(db, (name, columns) {
      if (name == tableName) {
        result = columns; // it's ok, dart pass the ptr. also clear & addAll or setAll .
        return true;
      }
      return false;
    });
    return result;
  }
}
