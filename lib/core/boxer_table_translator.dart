import 'dart:async';

import 'package:flutter_boxer_sqflite/core/features/boxer_delete_functions.dart';
import 'package:flutter_boxer_sqflite/core/features/boxer_insert_functions.dart';
import 'package:flutter_boxer_sqflite/core/features/boxer_query_functions.dart';
import 'package:flutter_boxer_sqflite/core/features/boxer_update_functions.dart';
import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';
import 'package:synchronized_call/synchronized_call.dart';

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
    Map<String, Object?>? outerMap = writeTranslator?.call(item);
    // override [outerMap] by the [translator] result specifiedOuterMap
    Map<String, Object?>? specifiedOuterMap = translator?.call(item);
    if (specifiedOuterMap != null) {
      outerMap?.addAll(specifiedOuterMap);
    }
    // item is the result if needed
    if (outerMap == null && item is Map) {
      outerMap = item is Map<String, Object?>
          ? item
          : Map<String, Object?>.from(item); // outerMap = item.cast<String, Object?>();
    }
    return outerMap;
  }
}

abstract class BoxerTableTranslator extends BoxerTableInterceptor
    with BoxerDeleteFunctions, BoxerInsertFunctions, BoxerQueryFunctions, BoxerUpdateFunctions {
  /**
   * Model Translate Methods
   */

  /// [ModelTranslatorFromJson] use for query model, [ModelTranslatorToJson] use for insert & update model
  static Map<Object, List> modelTranslators = {};

  static void setModelTranslator<T>(
    ModelTranslatorFromJson<T> fromJson,
    ModelTranslatorToJson<T> toJson,
    ModelIdentifyFields<T> uniqueFields,
  ) {
    modelTranslators[T] = [fromJson, toJson, uniqueFields];
  }

  static bool hasModelTranslator<T>() => modelTranslators.containsKey(T);

  static ModelTranslatorFromJson<T>? getModelTranslatorFrom<T>(ModelTranslatorFromJson<T>? fromJson) {
    List? list = BoxerTableTranslator.modelTranslators[T];
    fromJson ??= list?.atSafe(0) as ModelTranslatorFromJson<T>?;
    assert(fromJson != null, '❗️[$T] model\'s translator from json is null or not set/registered!');
    if (fromJson == null) {
      BoxerLogger.e(null, '❗️[$T] model\'s translator from json is null or not set/registered!');
    }
    return fromJson;
  }

  static ModelTranslatorToJson<T>? getModelTranslatorTo<T>(ModelTranslatorToJson<T>? toJson) {
    List? list = BoxerTableTranslator.modelTranslators[T];
    toJson ??= list?.atSafe(1) as ModelTranslatorToJson<T>?;
    assert(toJson != null, '❗️[$T] model\'s translator to json is null or not set/registered!');
    if (toJson == null) {
      BoxerLogger.e(null, '❗️[$T] model\'s translator to json is null or not set/registered!');
    }
    return toJson;
  }

  static ModelIdentifyFields<T>? getModelIdentifyFields<T>() {
    List? list = BoxerTableTranslator.modelTranslators[T];
    ModelIdentifyFields<T>? uniqueFieldGetter = list?.atSafe(2) as ModelIdentifyFields<T>?;
    if (uniqueFieldGetter == null) {
      BoxerLogger.d(null, '[$T] model\'s id <-> fields mapping is not set!');
    }
    return uniqueFieldGetter;
  }

  /**
   * Some operation with condition options
   */

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
typedef WriteTranslator<T> = Map<String, Object?> Function(T e);

/// function toJson/fromJson/id_fields for Model class
typedef ModelTranslatorToJson<T> = Map Function(T e);

typedef ModelTranslatorFromJson<T> = T Function(Map e);

typedef ModelIdentifyFields<T> = Map<String, dynamic> Function(T e);
