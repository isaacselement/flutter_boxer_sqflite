import 'dart:async';

import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';

///
///
/// Update Functions
///
///

mixin BoxerUpdateFunctions on BoxerTableInterceptor {
  /// using batch update the items if supported
  Future<int> mUpdates<T>(List<T> items, {BoxerQueryOption? options, WriteTranslator<T>? translator}) async {
    if (cloneInstance == null) {
      // CallLock lock = CallLock.get('$tableName.mUpdates');
      // return await lock.call<int>(() async {
      int count = 0;
      for (T item in items) {
        int c = await mUpdate<T>(item, options: options, translator: translator);
        if (c != -1) count += c;
      }
      return count;
      // });
    } else {
      // oh no ~~ result is empty list ...
      /* List<Object?>? result = */ await doBatch((clone) {
        clone as BoxerTableTranslator;
        for (T item in items) {
          mUpdate<T>(item, options: options, translator: translator);
        }
      });
      return items.length;
    }
  }

  /// using batch update the models if supported
  Future<int> mUpdateModels<T>(
    List<T> models, {
    BoxerQueryOption? options,
    ModelTranslatorToJson<T>? toJson,
    WriteTranslator<T>? translator,
  }) async {
    if (cloneInstance == null) {
      // CallLock lock = CallLock.get('$tableName.mUpdateModels');
      // return await lock.call<int>(() async {
      int count = 0;
      for (T model in models) {
        int c = await mUpdateModel<T>(model, toJson: toJson, options: options, translator: translator);
        if (c != -1) count += c;
      }
      return count;
      // });
    } else {
      // oh no ~~ result is empty list ...
      /* List<Object?>? result = */ await doBatch((clone) {
        clone as BoxerTableTranslator;
        for (T model in models) {
          mUpdateModel<T>(model, toJson: toJson, options: options, translator: translator);
        }
      });
      return models.length;
    }
  }

  /// T?, ? is needed
  Future<int> mUpdateModel<T>(
    T? model, {
    BoxerQueryOption? options,
    ModelTranslatorToJson<T>? toJson,
    WriteTranslator<T>? translator,
  }) async {
    ModelTranslatorToJson<T>? translate = BoxerTableTranslator.getModelTranslatorTo(toJson);
    if (translate == null || model == null) return 0;
    Map<String, Object?> values = Map<String, Object?>.from(translate(model));

    WriteTranslator<Map<String, Object?>>? translatorOuter = (e) => translator?.call(model) ?? {};
    Map<String, dynamic>? fields = BoxerTableTranslator.getModelIdentifyFields<T>()?.call(model);
    if (fields != null && fields.isNotEmpty) {
      options = BoxerQueryOption.eq(columns: fields.keys.toList(), values: fields.values.toList()).merge(options);
    }

    return await mUpdate(values, options: options, translator: translatorOuter);
  }

  Future<int> mUpdate<T>(T? item, {BoxerQueryOption? options, WriteTranslator<T>? translator}) async {
    Map<String, Object?>? map = translate2TableMap(item, translator: translator);
    assert(map != null, 'Values(${item.runtimeType}) update prohibited, should translate to a [Map] using translator');
    if (map == null) return 0;
    return await update(map, options: options, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
