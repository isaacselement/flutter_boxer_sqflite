import 'dart:async';

import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';

///
///
/// Insert Functions
///
///

mixin BoxerInsertFunctions on BoxerTableInterceptor {
  /// handler for caller when reached the maximum capacity or other situation you want to break
  FutureOr<bool> Function()? insertionsBreakHandler;

  /// Inset items
  Future<List<int>?> mInserts<T>(List<T> items, {WriteTranslator<T>? translator}) async {
    if ((await insertionsBreakHandler?.call()) == true) {
      BoxerLogger.d(null, "Insert $tableName bulk items broken, cause the [insertionsBreakHandler] return true!");
      return null;
    }

    /// Do list iteration to insert
    List<int> insertedIds = [];
    for (int i = 0; i < items.length; i++) {
      int identifier = await mInsert<T>(items[i], translator: translator);
      insertedIds.add(identifier);
    }
    BoxerLogger.d(null, "Inserted items ids is: $insertedIds");
    return insertedIds;
  }

  /// Insert models
  Future<List<int>?> mInsertModels<T>(List<T> models,
      {ModelTranslatorToJson<T>? toJson, WriteTranslator<T>? translator}) async {
    if ((await insertionsBreakHandler?.call()) == true) {
      BoxerLogger.d(null, "Insert $tableName bulk models broken, cause the [insertionsBreakHandler] return true!");
      return null;
    }

    /// Do list iteration to insert
    List<int> insertedIds = [];
    for (int i = 0; i < models.length; i++) {
      int identifier = await mInsertModel<T>(models[i], toJson: toJson, translator: translator);
      insertedIds.add(identifier);
    }
    BoxerLogger.d(null, "Inserted models ids is: $insertedIds");
    return insertedIds;
  }

  /// T?, ? is needed
  Future<int> mInsertModel<T>(T? model, {ModelTranslatorToJson<T>? toJson, WriteTranslator<T>? translator}) async {
    ModelTranslatorToJson<T>? translate = BoxerModelTranslator.getModelTranslatorTo(this, toJson);
    if (translate == null || model == null) return -1;
    Map<String, Object?> values = Map<String, Object?>.from(translate(model));

    WriteTranslator<Map<String, Object?>> translatorOuter;
    Map<String, dynamic>? fields = BoxerModelTranslator.getModelIdentifyFields<T>(this)?.call(model);
    if (fields != null && fields.isNotEmpty) {
      translatorOuter = (e, s) => fields..addAll(translator?.call(model, s) ?? {});
    } else {
      translatorOuter = (e, s) => translator?.call(model, s) ?? {};
    }
    return await mInsert(values, translator: translatorOuter);
  }

  Future<int> mInsert<T>(T? item, {WriteTranslator<T>? translator}) async {
    Map<String, Object?>? map = translate2TableMap(item, translator: translator);
    assert(map != null, "Values(${item.runtimeType}) that inserting to table should be a map.");
    if (map == null) return -1;
    return await insert(map, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
