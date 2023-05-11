import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';

abstract class BoxerTableBase {
  /// Database or Transaction instance
  late Database database;

  /// Subclass-Override, supply the table name
  String get tableName;

  /// Subclass-Override. When database configured
  Future<void> onConfigure(Database db) async {
    // nothing now ...
  }

  /// Subclass-Override. When database create, create table here
  Future<void> onCreate(Database db, int version) async {
    createTableIfNeeded(db: db, version: version);
  }

  /// Subclass-Override. When database upgrade, update table field here
  Future<void> onUpgrade(Database db, int oldVersion, int newVersion) async {
    createTableIfNeeded(db: db, version: newVersion);
  }

  /// Subclass-Override. When database downgrade, update table field here
  Future<void> onDowngrade(Database db, int oldVersion, int newVersion) async {
    // nothing now ...
  }

  /// Subclass-Override. When database opened, do some extra logic if you want
  Future<void> onOpen(Database db) async {
    // nothing now ...
  }

  /// Implement [createTableSpecification] to supply a table structure for conveniently creating table
  String? get createTableSpecification => null;

  Future<bool?> createTableIfNeeded({Database? db, int? version}) async {
    db ??= database;
    String? spec = createTableSpecification?.trim();
    if (spec == null) return null;
    List<String> strings = spec.split(';');

    /// get the create table sql
    String createTableSql = strings.firstSafe?.trim() ?? '';
    if (createTableSql.isEmpty) return null;
    createTableSql = createTableSql.removeLast(',');
    createTableSql = 'CREATE TABLE IF NOT EXISTS $tableName ( $createTableSql )';
    if (strings.length > 1) {
      /// with other sql like: 'CREATE UNIQUE INDEX IF NOT EXISTS $indexName ON $tableName ( columnName );'
      strings.removeAt(0);
      strings.insert(0, createTableSql);
    }
    for (String sql in strings) {
      try {
        BoxerLogger.i(null, 'Boxer createTableIfNeeded execute: $sql');
        await db.execute(sql);
      } catch (e, s) {
        BoxerLogger.f(null, 'Boxer createTableIfNeeded error: $e, $s');
        BoxerLogger.reportFatalError(e, s);
        return false;
      }
    }
    return isTableExisted();
  }

  /// [Database] and [Transaction] implements [DatabaseExecutor], [Batch]'s implementation is based on [Transaction]
  /// [Batch] contains all SQL interfaces that [DatabaseExecutor] have, but with void return
  Transaction? transaction;

  DatabaseExecutor get executor => transaction ?? database;

  /// If [batch] not null, we will use it for calling the corresponding SQL Api of [executor]
  Batch? batch;

  /// Usually subclass should implement `clone()` method for return a new instance returned by `clone()`
  /// This makes it easy to switch between [doTransaction] and [doBatch] operations, and keep the origin instance unchanged
  BoxerTableBase? clone() => null;

  BoxerTableBase? get cloneInstance => this.clone()?..database = database;

  /// Execute all sql in a transaction. See [BoxerTableTranslator.resetWithItems] for example usage
  Future<T?> doTransaction<T>(Future<T?> Function(BoxerTableBase clone) action, {bool? exclusive}) {
    return database.transaction<T?>((transaction) async {
      BoxerTableBase? clone = cloneInstance;
      assert(clone != null, '❗️❗️❗️You should implement the clone() method if u want use this [doTransaction] method');
      if (clone == null) return null;
      clone.transaction = transaction;
      return action(clone);
    }, exclusive: exclusive);
  }

  /// Execute all sql in a batch(essentially transaction).  See [BoxerTableTranslator.resetWithItems] for example usage
  Future<List<Object?>?> doBatch(void Function(BoxerTableBase clone) action, {bool? exclusive}) async {
    BoxerTableBase? clone = cloneInstance;
    assert(clone != null, '❗️❗️❗️You should implement the clone() method if u want use this [doBatch] method');
    if (clone == null) return null;
    clone.batch = clone.database.batch();
    action(clone);
    return await clone.batch?.commit(exclusive: exclusive);
  }

  /**
   * Basic table records query/insert/update/delete operations
   */

  /// Insert. Return the id of the last inserted row. 0 or -1 maybe returned if insert failed.
  Future<int> insert(Map<String, Object?> values,
      {ConflictAlgorithm? conflictAlgorithm, bool isReThrow = false}) async {
    try {
      batch?.insert(tableName, values, conflictAlgorithm: conflictAlgorithm);
      if (batch != null) return 0; // fake result, please get the real result from `batch.commit()`
      return await executor.insert(tableName, values, conflictAlgorithm: conflictAlgorithm);
    } catch (e, s) {
      /// Prevent retry recursion, thrown to the caller
      if (isReThrow) rethrow;

      /// Retry create table and do insert again
      if (e is DatabaseException && e.isNoSuchTableError()) {
        if ((await createTableIfNeeded()) == true) {
          return await insert(values, conflictAlgorithm: conflictAlgorithm, isReThrow: true);
        }
      }
      BoxerLogger.f(null, 'Insert error: $e, $s');
      BoxerLogger.reportFatalError(e, s);
      return -1;
    }
  }

  /// Query
  Future<List<Map<String, Object?>>> query({
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    batch?.query(
      tableName,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    if (batch != null) return []; // fake result, please get the real result from `batch.commit()`
    return await executor.query(
      tableName,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  /// Update
  Future<int> update(Map<String, Object?> values,
      {String? where, List<Object?>? whereArgs, ConflictAlgorithm? conflictAlgorithm}) async {
    batch?.update(tableName, values, where: where, whereArgs: whereArgs, conflictAlgorithm: conflictAlgorithm);
    if (batch != null) return 0; // fake result, please get the real result from `batch.commit()`
    return await executor.update(tableName, values,
        where: where, whereArgs: whereArgs, conflictAlgorithm: conflictAlgorithm);
  }

  /// Delete
  Future<int> delete({String? where, List<Object?>? whereArgs}) async {
    batch?.delete(tableName, where: where, whereArgs: whereArgs);
    if (batch != null) return 0; // fake result, please get the real result from `batch.commit()`
    return await executor.delete(tableName, where: where, whereArgs: whereArgs);
  }

  /**
   * Some useful method for handling table
   */

  /// Check if current table existed
  Future<bool> isTableExisted() async {
    return await BoxerDatabaseUtil.isTableExistedRaw(executor, tableName);
  }

  /// Number of rows in current table, null if result mismatch
  Future<int?> selectCount({String? where, List<Object?>? whereArgs}) async {
    return await BoxerDatabaseUtil.selectCountRaw(executor, tableName, where: where, whereArgs: whereArgs);
  }

  /// Select Max of column value
  Future<Object?> selectMax(String column) async {
    return await BoxerDatabaseUtil.selectMaxRaw(executor, tableName, column);
  }

  /// Select Min of column value
  Future<Object?> selectMin(String column) async {
    return await BoxerDatabaseUtil.selectMinRaw(executor, tableName, column);
  }

  /// Select Min of column value
  Future<void> resetAutoId() async {
    return await BoxerDatabaseUtil.resetAutoIdRaw(executor, tableName: tableName);
  }
}
