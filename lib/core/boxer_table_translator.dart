import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:synchronized_call/synchronized_call.dart';
import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';

abstract class BoxerTableTranslator extends BoxerTableBase {
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
    return await super.update(values, where: options.where, whereArgs: options.whereArgs, conflictAlgorithm: conflictAlgorithm);
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

  /** Query **/

  /// [mQueryAsModels] based on a Json-Object (Map or List)
  ///
  /// [fromJson] is the function that tell to callee how to translate result to model object
  Future<List<T>> mQueryAsModels<T>({ModelTranslatorFromJson<T>? fromJson, BoxerQueryOption? options}) async {
    ModelTranslatorFromJson<T>? translate = BoxerTableTranslator.getModelTranslatorFrom(fromJson);
    if (translate == null) return [];
    return (await mQueryAsMap(options: options)).map((e) => translate(e)).toList();
  }

  Future<List<Map>> mQueryAsMap({BoxerQueryOption? options}) => mQueryAsJson<Map>(options: options);

  Future<List<List>> mQueryAsList({BoxerQueryOption? options}) => mQueryAsJson<List>(options: options);

  /// translate it to T, T should be a Json-Object (Map or List) Type
  Future<List<T>> mQueryAsJson<T>({BoxerQueryOption? options}) async {
    return (await mQueryAsStrings(options: options)).map<T>((string) {
      T? result;
      try {
        result = string.isNotEmpty ? json.decode(string) as T : null;
      } catch (e, s) {
        BxLoG.d('❗️❗️❗️ERROR: query as json decode error: $e, $s');
        // rethrow;
      }
      return result ?? (T.toString() == [].runtimeType.toString() ? [] : {}) as T;
    }).toList();
  }

  Future<List<String>> mQueryAsStrings({BoxerQueryOption? options}) async {
    return (await mQueryAsObjects(options: options)).map<String>((e) => e?.toString() ?? '').toList();
  }

  /// Query and cast the result to specified object type, or filter the result using [queryAsTranslator]
  Object? Function(Map<String, Object?> element)? queryAsTranslator;

  /// Query the element or it's one column value using [queryAsTranslator]
  Future<List<Object?>> mQueryAsObjects({Object? Function(Map<String, Object?> item)? translator, BoxerQueryOption? options}) async {
    return await mQueryTo<Object?>(
      options: options,
      translator: (Map<String, Object?> element) {
        translator ??= queryAsTranslator;
        return translator != null ? translator!(element) : element;
      },
    );
  }

  /// Query and translate the values to a specified object models
  Future<List<T>> mQueryTo<T>({required T Function(Map<String, Object?> item) translator, BoxerQueryOption? options}) async {
    List<Map<String, Object?>> values = await query(options: options);
    List<T> results = values.map((element) => translator(element)).toList();
    return results;
  }

  /** Insert **/

  /// handler for caller when reached the maximum capacity or other situation you want to break
  FutureOr<bool> Function()? insertionsBreakHandler;

  Future<List<int>?> mInserts<T>(List<T> items, {InsertionTranslator<T>? translator}) async {
    if ((await insertionsBreakHandler?.call()) == true) {
      BxLoG.d('$tableName insert bulk items broken, cause the [insertionsBreakHandler] return true!');
      return null;
    }

    /// Do list iteration to insert
    List<int> insertedIds = [];
    for (int i = 0; i < items.length; i++) {
      int identifier = await mInsert<T>(items[i], translator: translator);
      if (identifier > 0) {
        insertedIds.add(identifier);
      }
    }
    BxLoG.d('Inserted items ids is: $insertedIds');
    return insertedIds;
  }

  /// T?, ? is needed
  Future<int> mInsertModel<T>(T? model, {ModelTranslatorToJson<T>? toJson, InsertionTranslator<T>? translator}) async {
    ModelTranslatorToJson<T>? translate = BoxerTableTranslator.getModelTranslatorTo(toJson);
    if (translate == null || model == null) return -1;
    Map<String, Object?> values = Map<String, Object?>.from(translate(model));

    InsertionTranslator<Map<String, Object?>>? mapTr = (e) => translator?.call(model) ?? {};
    Map<String, dynamic>? fields = getModelIdentifyFields<T>()?.call(model);
    if (fields != null && fields.isNotEmpty) {
      mapTr = (e) => fields..addAll(translator?.call(model) ?? {});
    }
    return await mInsert(values, translator: mapTr);
  }

  Future<int> mInsert<T>(T? item, {InsertionTranslator<T>? translator}) async {
    Map<String, Object?>? map = toMap(item, translator: translator);
    assert(map != null, 'Values(${item.runtimeType}) that inserting to table should be a map.');
    if (map == null) return -1;
    return await insert(map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /** Update **/

  /// T?, ? is needed
  Future<int> mUpdateModel<T>(T? model, {ModelTranslatorToJson<T>? toJson, BoxerQueryOption? options}) async {
    ModelTranslatorToJson<T>? translate = BoxerTableTranslator.getModelTranslatorTo(toJson);
    if (translate == null || model == null) return -1;
    Map<String, Object?> values = Map<String, Object?>.from(translate(model));

    Map<String, dynamic>? fields = getModelIdentifyFields<T>()?.call(model);
    if (fields != null && fields.isNotEmpty) {
      options = BoxerQueryOption.eq(columns: fields.keys.toList(), values: fields.values.toList()).merge(options);
    }
    return await mUpdate(values, options: options);
  }

  Future<int> mUpdate<T>(T? item, {InsertionTranslator<T>? translator, BoxerQueryOption? options}) async {
    Map<String, Object?>? map = toMap(item, translator: translator);
    assert(map != null, 'Values(${item.runtimeType}) that updating to table should be a map.');
    if (map == null) return -1;
    return await update(map, options: options, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /**
   * Wrap Methods
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

  static ModelTranslatorFromJson<T>? getModelTranslatorFrom<T>(ModelTranslatorFromJson<T>? fromJson) {
    List? list = BoxerTableTranslator.modelTranslators[T];
    fromJson ??= list?.atSafe(0) as ModelTranslatorFromJson<T>?;
    assert(fromJson != null, '❗️[$T] model\'s translator from json is null or not set/registered!');
    return fromJson;
  }

  static ModelTranslatorToJson<T>? getModelTranslatorTo<T>(ModelTranslatorToJson<T>? toJson) {
    List? list = BoxerTableTranslator.modelTranslators[T];
    toJson ??= list?.atSafe(1) as ModelTranslatorToJson<T>?;
    assert(toJson != null, '❗️[$T] model\'s translator to json is null or not set/registered!');
    return toJson;
  }

  static ModelIdentifyFields<T>? getModelIdentifyFields<T>() {
    List? list = BoxerTableTranslator.modelTranslators[T];
    ModelIdentifyFields<T>? uniqueFieldGetter = list?.atSafe(2) as ModelIdentifyFields<T>?;
    if (uniqueFieldGetter == null) {
      BxLoG.d('No ModelIdentifyFields set/registered for $T');
    }
    return uniqueFieldGetter;
  }

  /// Low level translator for inserting/updating item, in [mInsert] & [mUpdate] method
  InsertionTranslator? insertionTranslator;

  Map<String, Object?>? toMap<T>(T? item, {InsertionTranslator<T>? translator}) {
    if (item == null) return null;

    /// TODO ... call [mInsertModel]/[mUpdateModel] method and not translate to OuterMap will get a crash that record in README.md
    Map<String, Object?>? outerMap = insertionTranslator?.call(item);
    // cover outerMap by specifiedOuterMap
    Map<String, Object?>? specifiedOuterMap = translator?.call(item);
    if (specifiedOuterMap != null) {
      outerMap?.addAll(specifiedOuterMap);
    }
    // item is the result if needed
    if (outerMap == null && item is Map) {
      outerMap = item is Map<String, Object?> ? item : Map<String, Object?>.from(item); // outerMap = item.cast<String, Object?>();
    }
    return outerMap;
  }

  /**
   * Some operation with condition options
   */

  /// Number of rows
  Future<int?> count([BoxerQueryOption? options]) async {
    return await selectCount(where: options?.where, whereArgs: options?.whereArgs);
  }

  /// Clear rows
  Future<int> clear([BoxerQueryOption? options]) async {
    return await delete(where: options?.where, whereArgs: options?.whereArgs);
  }

  /// Using the lock, for making `Clear and Insert` jobs execute in serial queue
  CallLock mOperationsSyncLock = CallLock.create();

  /// Do clear & insert operation. [option] for clear filter, [translator] for insertion transform
  Future<List<Object?>?> resetWithItems<T>(
    List<T> items, {
    BoxerQueryOption? option,
    InsertionTranslator<T>? translator,
    BatchSyncType? syncType = BatchSyncType.LOCK,
  }) async {
    /// Using a sync lock
    if (syncType == BatchSyncType.LOCK) {
      return await mOperationsSyncLock.call<List<int>?>(() async {
        await clear(option);
        return await mInserts<T>(items, translator: translator);
      });
    }

    /// Using batch
    if (syncType == BatchSyncType.BATCH) {
      return await doBatch((clone) {
        clone as BoxerTableTranslator;
        clone.clear(option);
        clone.mInserts<T>(items, translator: translator);
      });
    }

    /// Using the transaction
    if (syncType == BatchSyncType.TRANSACTION) {
      return await doTransaction((clone) async {
        clone as BoxerTableTranslator;
        await clone.clear(option);
        return await clone.mInserts<T>(items, translator: translator);
      });
    }

    /// Note, set syncType to null is unsafe if method re-entrance many times immediately
    /// In other words, it is safe when method enter once or re-enter after a long time, the scenario that you really know about
    await clear(option);
    return await mInserts<T>(items, translator: translator);
  }
}

enum BatchSyncType { LOCK, BATCH, TRANSACTION }

/// insert or update, translate to item to Map
typedef InsertionTranslator<T> = Map<String, Object?> Function(T e);

/// function toJson/fromJson/id_fields for Model class
typedef ModelTranslatorToJson<T> = Map Function(T e);

typedef ModelTranslatorFromJson<T> = T Function(Map e);

typedef ModelIdentifyFields<T> = Map<String, dynamic> Function(T e);
