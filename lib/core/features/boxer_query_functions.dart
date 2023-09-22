import 'dart:convert';

import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';

///
///
/// Query Functions
///
///

mixin BoxerQueryFunctions on BoxerTableInterceptor {
  /// Attention: [single] will throw StateError if result-list is not a non-null single element
  Future<T> single<T>({BoxerQueryOption? options, ModelTranslatorFromJson<T>? fromJson}) async {
    List<T?> result = await list<T>(options: options, fromJson: fromJson);
    T? single = result.single;
    if (single == null) {
      throw StateError("single element is null");
    }
    return single;
  }

  // Important!!! ensure just only one result, otherwise return null (for many or zero results)
  Future<T?> one<T>({BoxerQueryOption? options, ModelTranslatorFromJson<T>? fromJson}) async {
    return (await list<T>(options: options, fromJson: fromJson)).singleSafe;
  }

  // NOTE: options should have nonnull orderBy, now is just the first on list
  Future<T?> first<T>({BoxerQueryOption? options, ModelTranslatorFromJson<T>? fromJson}) async {
    return (await list<T>(options: options, fromJson: fromJson)).firstSafe;
  }

  // NOTE: options should have nonnull orderBy, now is just the last on list
  Future<T?> last<T>({BoxerQueryOption? options, ModelTranslatorFromJson<T>? fromJson}) async {
    return (await list<T>(options: options, fromJson: fromJson)).lastSafe;
  }

  Future<List<T?>> list<T>({BoxerQueryOption? options, ModelTranslatorFromJson<T>? fromJson}) async {
    List<T?> results;

    if (T == int || T == double) {
      results = List<T?>.from(await mQueryAsNum(options: options));
    } else if (T == num) {
      results = await mQueryAsNum(options: options) as List<T?>;
    } else if (T == String) {
      results = await mQueryAsStrings(options: options) as List<T?>;
    } else if (T == Map) {
      results = await mQueryAsMap(options: options) as List<T?>;
    } else if (T == List) {
      results = await mQueryAsList(options: options) as List<T?>;
    } else {
      /// if has model translator already ?
      if (fromJson != null || BoxerTableTranslator.hasModelTranslator<T>()) {
        return await mQueryAsModels<T>(options: options, fromJson: fromJson);
      }
      List<Object?> list = await mQuery(options: options);

      /// if T is bool type, cast it to bool
      if (T == bool) {
        results = list.map(BoxerQueryFunctions.toBool).toList() as List<T?>;
      } else {
        results = List<T?>.from(list);
      }
    }
    return results;
  }

  static bool toBool(dynamic e) {
    if (e == null) {
      return false;
    } else if (e is bool) {
      return e;
    } else if (e is num) {
      return e == 1;
    } else {
      String? v = e?.toString().toLowerCase();
      return v == "1" || v == "true" || v == "yes";
    }
  }

  /// translate model based on a Json-Object Map, [fromJson] indicate that how-to translate Map to model T object
  Future<List<T>> mQueryAsModels<T>({ModelTranslatorFromJson<T>? fromJson, BoxerQueryOption? options}) async {
    ModelTranslatorFromJson<T>? translate = BoxerTableTranslator.getModelTranslatorFrom<T>(fromJson);
    if (translate == null) return [];
    return (await mQueryAsMap(options: options)).map((e) => translate(e)).toList();
  }

  /// translate it to Json Map
  Future<List<Map>> mQueryAsMap({BoxerQueryOption? options}) async {
    return await mQueryAsJson<Map>(options: options);
  }

  /// translate it to Json List
  Future<List<List>> mQueryAsList({BoxerQueryOption? options}) async {
    return await mQueryAsJson<List>(options: options);
  }

  /// translate it to Json-Object (Map or List)
  Future<List<T>> mQueryAsJson<T>({BoxerQueryOption? options}) async {
    return (await mQueryAsStrings(options: options)).map<T>((string) {
      T? result;
      try {
        result = string != null && string.isNotEmpty ? (json.decode(string) as T) : null;
      } catch (e, s) {
        BoxerLogger.e(null, "❗️❗️❗️ERROR: query as json decode error: $e, $s");
        // rethrow;
      }
      if (result != null) {
        return result;
      }
      String type = T.toString();
      bool isNullable = type.endsWith("?");
      if (isNullable) {
        return null as T;
      }
      bool isList = type.contains("List");
      return (isList ? [] : {}) as T;
    }).toList();
  }

  /// translate it to num (double or int)
  Future<List<num?>> mQueryAsNum({BoxerQueryOption? options}) async {
    return (await mQuery(options: options)).map<num?>((e) {
      if (e is num?) return e;
      return num.tryParse(e.toString());
    }).toList();
  }

  /// translate it to String
  Future<List<String?>> mQueryAsStrings({BoxerQueryOption? options}) async {
    return (await mQuery(options: options)).map<String?>((e) {
      if (e is String?) return e;
      return e.toString();
    }).toList();
  }

  /// Query and cast the result to generic object type
  Future<List<Object?>> mQuery({QueryTranslator? translator, BoxerQueryOption? options}) async {
    return await mQueryTo<Object?>(
      options: options,
      translator: (Map<String, Object?> element) {
        QueryTranslator? fn = translator ?? queryTranslator;
        return fn != null ? fn(element) : element;
      },
    );
  }

  /// Query and translate the values to a specified object models
  Future<List<T>> mQueryTo<T>({
    required QueryTranslator<T> translator,
    BoxerQueryOption? options,
  }) async {
    List<Map<String, Object?>> values = await query(options: options);
    List<T> results = values.map((element) => translator(element)).toList();
    return results;
  }
}
