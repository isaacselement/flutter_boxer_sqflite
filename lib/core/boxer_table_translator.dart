import 'dart:async';

import 'package:flutter_boxer_sqflite/core/features/boxer_delete_functions.dart';
import 'package:flutter_boxer_sqflite/core/features/boxer_insert_functions.dart';
import 'package:flutter_boxer_sqflite/core/features/boxer_query_functions.dart';
import 'package:flutter_boxer_sqflite/core/features/boxer_update_functions.dart';
import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';
import 'package:synchronized_call/synchronized_call.dart';

class BoxerModelTranslator {
  /// [ModelTranslatorFromJson] for query, [ModelTranslatorToJson] & [ModelIdentifyFields] for insert & update model
  static Map<Object, List> modelTranslators = {};

  static void setModelTranslator<T>(
    ModelTranslatorFromJson<T> fromJson,
    ModelTranslatorToJson<T> toJson,
    ModelIdentifyFields<T> uniqueFields,
  ) {
    modelTranslators[T] = [fromJson, toJson, uniqueFields];
  }

  static bool hasModelTranslator<T>([BoxerTableBase? table]) {
    if (table is BoxerTableTranslator && table.modelTranslators.containsKey(T)) return true;
    return modelTranslators.containsKey(T);
  }

  static ModelTranslatorFromJson<T>? getModelTranslatorFrom<T>(
      [BoxerTableBase? table, ModelTranslatorFromJson<T>? fromJson]) {
    if (fromJson != null) return fromJson;

    Map<Object, List>? instanceTranslators = table is BoxerTableTranslator ? table.modelTranslators : null;
    List? list = (instanceTranslators?[T]) ?? modelTranslators[T];

    fromJson ??= list?.atSafe(0) as ModelTranslatorFromJson<T>?;
    assert(fromJson != null, '❗️[$T] model\'s translator from json is null or not set/registered!');
    if (fromJson == null) {
      BoxerLogger.e(null, '❗️[$T] model\'s translator from json is null or not set/registered!');
    }
    return fromJson;
  }

  static ModelTranslatorToJson<T>? getModelTranslatorTo<T>([BoxerTableBase? table, ModelTranslatorToJson<T>? toJson]) {
    if (toJson != null) return toJson;

    Map<Object, List>? instanceTranslators = table is BoxerTableTranslator ? table.modelTranslators : null;
    List? list = (instanceTranslators?[T]) ?? modelTranslators[T];

    toJson ??= list?.atSafe(1) as ModelTranslatorToJson<T>?;
    assert(toJson != null, '❗️[$T] model\'s translator to json is null or not set/registered!');
    if (toJson == null) {
      BoxerLogger.e(null, '❗️[$T] model\'s translator to json is null or not set/registered!');
    }
    return toJson;
  }

  static ModelIdentifyFields<T>? getModelIdentifyFields<T>([BoxerTableBase? table]) {
    Map<Object, List>? instanceTranslators = table is BoxerTableTranslator ? table.modelTranslators : null;
    List? list = (instanceTranslators?[T]) ?? modelTranslators[T];

    ModelIdentifyFields<T>? uniqueFieldGetter = list?.atSafe(2) as ModelIdentifyFields<T>?;
    if (uniqueFieldGetter == null) {
      BoxerLogger.d(null, '[$T] model\'s id <-> fields mapping is not set!');
    }
    return uniqueFieldGetter;
  }
}

abstract class BoxerTableInterceptor extends BoxerTableBase {
  void onQuery(BoxerQueryOption options);

  void onDelete(BoxerQueryOption options);

  void onInsertValues(Map<String, Object?> values);

  void onUpdateValues(Map<String, Object?> values, BoxerQueryOption options);

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
    // Note: if the [options] parameter provided, the other query parameters is ignored!
    BoxerQueryOption? options,
  }) async {
    options ??= BoxerQueryOption()
      ..distinct = distinct
      ..columns = columns
      ..where = where
      ..whereArgs = whereArgs
      ..groupBy = groupBy
      ..having = having
      ..orderBy = orderBy
      ..limit = limit
      ..offset = offset;
    onQuery(options);
    return await super.query(
      distinct: options.distinct,
      columns: options.columns,
      where: options.where,
      whereArgs: options.whereArgs,
      groupBy: options.groupBy,
      having: options.having,
      orderBy: options.orderBy,
      limit: options.limit,
      offset: options.offset,
    );
  }

  /// Insert
  Future<int> insert(
    Map<String, Object?> values, {
    ConflictAlgorithm? conflictAlgorithm,
    bool isReThrow = false,
  }) async {
    onInsertValues(values);
    return await super.insert(values, conflictAlgorithm: conflictAlgorithm, isReThrow: isReThrow);
  }

  /// Update
  Future<int> update(
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
    // Note: if the [options] parameter provided, the other query parameters is ignored!
    BoxerQueryOption? options,
  }) async {
    options ??= BoxerQueryOption()
      ..where = where
      ..whereArgs = whereArgs;
    onUpdateValues(values, options);
    return await super
        .update(values, where: options.where, whereArgs: options.whereArgs, conflictAlgorithm: conflictAlgorithm);
  }

  /// Delete
  Future<int> delete({
    String? where,
    List<Object?>? whereArgs,
    // Note: if the [options] parameter provided, the other query parameters is ignored!
    BoxerQueryOption? options,
  }) async {
    options ??= BoxerQueryOption()
      ..where = where
      ..whereArgs = whereArgs;
    onDelete(options);
    return await super.delete(where: options.where, whereArgs: options.whereArgs);
  }

  /// Low level translator for query item, called in [mQuery] method
  QueryTranslator? queryTranslator;

  /// Low level translator for inserting/updating item, called in [mInsert] & [mUpdate] method
  WriteTranslator? writeTranslator;

  Map<String, Object?>? translate2TableMap<T>(T? item, {WriteTranslator<T>? translator}) {
    if (item == null) return null;

    /// TODO ... call [mInsertModel]/[mUpdateModel] method and not translate to OuterMap will get a crash that record in README.md
    Map<String, Object?>? map = writeTranslator?.call(item, null);
    Map<String, Object?>? specifiedMap = translator?.call(item, map);

    /// override [map] existed keys-values by the [translator]'s result specifiedOuterMap
    if (specifiedMap != null) {
      map == null ? map = specifiedMap : map.addAll(specifiedMap);
    }

    /// if [map] is empty and [specifiedMap] is null, set map to null to give chance to the item
    if (specifiedMap == null && (map?.isEmpty ?? false)) {
      map = null;
    }

    /// item is the outer table-mapping map if item got the chance
    if (map == null && item is Map) {
      map = item is Map<String, Object?>
          ? item
          : Map<String, Object?>.from(item); // outerMap = item.cast<String, Object?>();
    }
    return map;
  }
}

abstract class BoxerTableTranslator extends BoxerTableInterceptor
    with BoxerDeleteFunctions, BoxerInsertFunctions, BoxerQueryFunctions, BoxerUpdateFunctions {
  /// Instance variables corresponding to [BoxerModelTranslator] properties
  Map<Object, List> modelTranslators = {};

  void setModelTranslator<T>(
    ModelTranslatorFromJson<T> fromJson,
    ModelTranslatorToJson<T> toJson,
    ModelIdentifyFields<T> uniqueFields,
  ) {
    modelTranslators[T] = [fromJson, toJson, uniqueFields];
  }

  /// Get column value
  Future<Object?> getColumnValue(String column, {BoxerQueryOption? options}) async {
    return (await mQuery(options: options, translator: (e) => e[column])).firstSafe;
  }

  /// Set column value
  Future<int> setColumnValue(String column, Object? value, {BoxerQueryOption? options}) async {
    return await mUpdate<Object>(value, options: options, translator: (e, s) {
      s?.clear();
      return {column: value};
    });
  }

  /// Number of rows
  Future<int?> count([BoxerQueryOption? options]) async {
    return await selectCount(where: options?.where, whereArgs: options?.whereArgs);
  }

  /// Using the lock, for making `Clear and Insert` jobs execute in serial queue
  CallLock callLock4ResetItems = CallLock.create();

  /// Do clear & insert operation. [option] for clear filter, [translator] for insertion transform
  Future<List<Object?>?> resetWithItems<T>(
    List<T> items, {
    BoxerQueryOption? option,
    WriteTranslator<T>? translator,
    BatchSyncType? syncType = BatchSyncType.LOCK,
  }) async {
    /// Using a sync lock
    if (syncType == BatchSyncType.LOCK) {
      return await callLock4ResetItems.call<List<int>?>(() async {
        await delete(options: option);
        return await mInserts<T>(items, translator: translator);
      });
    }

    /// Using batch
    if (syncType == BatchSyncType.BATCH) {
      return await doBatch((clone) {
        clone as BoxerTableTranslator;
        clone.delete(options: option);
        clone.mInserts<T>(items, translator: translator);
      });
    }

    /// Using the transaction
    if (syncType == BatchSyncType.TRANSACTION) {
      return await doTransaction((clone) async {
        clone as BoxerTableTranslator;
        await clone.delete(options: option);
        return await clone.mInserts<T>(items, translator: translator);
      });
    }

    /// Note, set syncType to null is unsafe if method re-entrance many times immediately
    /// In other words, it is safe when method enter once or re-enter after a long time, the scenario that you really know about
    await delete(options: option);
    return await mInserts<T>(items, translator: translator);
  }
}

/// In terms of intuitive efficiency, BATCH is the best, BATCH > TRANSACTION > LOCK
enum BatchSyncType { LOCK, BATCH, TRANSACTION }

/// query translator for translate the table struct columns Map value to item we needed
typedef QueryTranslator<T> = T Function(Map<String, Object?> e);

/// insert or update, translate to item that mapping the table struct columns Map
typedef WriteTranslator<T> = Map<String, Object?> Function(T e, Map<String, Object?>? s);

/// function toJson/fromJson/id_fields for Model class
typedef ModelTranslatorToJson<T> = Map Function(T e);

typedef ModelTranslatorFromJson<T> = T Function(Map e);

typedef ModelIdentifyFields<T> = Map<String, dynamic> Function(T e);
