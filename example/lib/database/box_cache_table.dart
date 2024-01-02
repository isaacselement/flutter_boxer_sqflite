import 'dart:async';
import 'dart:convert';

import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';
import 'package:synchronized_call/synchronized_call.dart';

class BoxCacheTable extends BoxerTableTranslator {
  static const String TAG = 'BoxCacheTable';

  static const String kCOLUMN_ID = 'ID';
  static const String kCOLUMN_ITEM_ID = 'ITEM_ID';
  static const String kCOLUMN_ITEM_TYPE = 'ITEM_TYPE';
  static const String kCOLUMN_ITEM_VALUE = 'ITEM_VALUE';
  static const String kCOLUMN_CREATE_TIME = 'CREATE_TIME';
  static const String kCOLUMN_UPDATE_TIME = 'UPDATE_TIME';
  static const String kCOLUMN_USER_ID = 'USER_ID';
  static const String kCOLUMN_ROLE_ID = 'ROLE_ID';

  static int currentUserId = 0;
  static int currentRoleId = 0;

  BoxCacheTable({required String tableName}) : super() {
    _tableName = tableName;

    insertionsBreakHandler = () async {
      // Limit the number of entries to a specified capacity to avoid infinite insertion
      int? capacity = 5000;
      if ((await selectCount() ?? 0) > capacity) {
        BoxerLogger.e(TAG, '$tableName insert exceed limits capacity $capacity !');
        return true;
      }
      return false;
    };

    queryTranslator = (Map<String, Object?> element) {
      Object? value = element[kCOLUMN_ITEM_VALUE];

      /// TODO ... Decryption ...
      return value;
    };

    writeTranslator = (dynamic item, Map<String, Object?>? values) {
      Object? value;
      if (/* item is bool || */ item is num || item is String) {
        /// primitive type
        value = item;
      } else if (item is Map || item is List) {
        /// json type
        value = json.encode(item);
      } else {
        /// try-to call model model's `toJson` method
        try {
          var _toJson = item?.toJson;
          value = _toJson != null && _toJson is Function ? json.encode(item.toJson.call()) : null;
        } catch (e) {
          /// ignore this error ...
        }
      }
      value ??= item?.toString();

      /// TODO ... Encryption ...
      return {kCOLUMN_ITEM_VALUE: value};
    };
  }

  late String _tableName;
  bool isRoleIdConcerned = true;
  bool isUserIdConcerned = true;

  @override
  String get tableName => _tableName;

  @override
  String? get createTableSpecification => ''
      '$kCOLUMN_ID INTEGER PRIMARY KEY AUTOINCREMENT, '
      '$kCOLUMN_ITEM_ID TEXT, '
      '$kCOLUMN_ITEM_TYPE TEXT, '
      '$kCOLUMN_ITEM_VALUE TEXT, '
      '$kCOLUMN_CREATE_TIME INTEGER, '
      '$kCOLUMN_UPDATE_TIME INTEGER, '
      '$kCOLUMN_USER_ID INTEGER, '
      '$kCOLUMN_ROLE_ID INTEGER, '
      // use SEPARATOR ';' to supply every extra execute/create sql something like `CREATE INDEX ...`
      ';'
      // 'CREATE UNIQUE INDEX IF NOT EXISTS Uq_${kCOLUMN_ITEM_ID}_$tableName ON $tableName ( $kCOLUMN_ITEM_ID )';
      'CREATE INDEX IF NOT EXISTS Idx_${kCOLUMN_ITEM_ID}_$tableName ON $tableName ( $kCOLUMN_ITEM_ID )';

  @override
  BoxerTableBase? clone() => BoxCacheTable(tableName: this.tableName)
    ..isRoleIdConcerned = this.isRoleIdConcerned
    ..isUserIdConcerned = this.isUserIdConcerned;

  @override
  void onQuery(BoxerQueryOption options) {
    optionsWithUserRoleId(options);
  }

  @override
  void onDelete(BoxerQueryOption options) {
    optionsWithUserRoleId(options);
  }

  @override
  void onInsertValues(Map<String, Object?> values) {
    values['$kCOLUMN_CREATE_TIME'] = DateTime.now().millisecondsSinceEpoch;
    if (isUserIdConcerned) {
      values[kCOLUMN_USER_ID] ??= currentUserId;
    }
    if (isRoleIdConcerned) {
      values[kCOLUMN_ROLE_ID] ??= currentRoleId;
    }
  }

  @override
  void onUpdateValues(Map<String, Object?> values, BoxerQueryOption options) {
    values['$kCOLUMN_UPDATE_TIME'] = DateTime.now().millisecondsSinceEpoch;
    optionsWithUserRoleId(options);
  }

  BoxerQueryOption optionsWithUserRoleId(BoxerQueryOption options) {
    BoxerQueryOption? opUserId = null;
    BoxerQueryOption? opRoleId = null;
    if (isUserIdConcerned) {
      opUserId = BoxerQueryOption.e(column: kCOLUMN_USER_ID, value: currentUserId);
    }
    if (isRoleIdConcerned) {
      opRoleId = BoxerQueryOption.e(column: kCOLUMN_ROLE_ID, value: currentRoleId);
    }
    BoxerQueryOption? op = null;
    if (opUserId != null && opRoleId != null) {
      op = BoxerQueryOption.merge([opUserId, opRoleId]).group();
    } else {
      op = opUserId ?? opRoleId;
    }
    if (op != null) {
      options.insert(where: op.where, whereArgs: op.whereArgs, isInsertInFront: true);
    }
    return options;
  }

  /**
   * Override BoxerQueryFunctions methods
   */

  @override
  Future<T?> one<T>({
    String? type,
    String? itemId,
    BoxerQueryOption? options,
    ModelTranslatorFromJson<T>? fromJson,
    bool isReThrow = false,
  }) async {
    try {
      BoxerQueryOption op = getOptions(id: null, type: type, itemId: itemId);
      op = options?.merge(op) ?? op;
      return await super.one<T>(options: op, fromJson: fromJson);
    } catch (e, s) {
      if (isReThrow) rethrow;
      BoxerLogger.e(TAG, '$tableName method [one] error: $e, $s');
    }
    return null;
  }

  @override
  Future<T?> first<T>({
    String? type,
    String? itemId,
    BoxerQueryOption? options,
    ModelTranslatorFromJson<T>? fromJson,
    bool isReThrow = false,
  }) async {
    try {
      BoxerQueryOption op = getOptions(id: null, type: type, itemId: itemId);
      op = options?.merge(op) ?? op;
      op.orderBy = kCOLUMN_ID;
      return await super.first<T>(options: op, fromJson: fromJson);
    } catch (e, s) {
      if (isReThrow) rethrow;
      BoxerLogger.e(TAG, '$tableName method [first] error: $e, $s');
    }
    return null;
  }

  @override
  Future<T?> last<T>({
    String? type,
    String? itemId,
    BoxerQueryOption? options,
    ModelTranslatorFromJson<T>? fromJson,
    bool isReThrow = false,
  }) async {
    try {
      BoxerQueryOption op = getOptions(id: null, type: type, itemId: itemId);
      op = options?.merge(op) ?? op;
      op.orderBy = kCOLUMN_ID;
      return await super.last<T>(options: op, fromJson: fromJson);
    } catch (e, s) {
      if (isReThrow) rethrow;
      BoxerLogger.e(TAG, '$tableName method [last] error: $e, $s');
    }
    return null;
  }

  /// use [fromJson] to translate to model [T]
  /// if [fromJson] is null, the translator that registered in [BoxerTableTranslator.modelTranslators] will be use
  /// or call results' [Iterable.map<T>(T fn(E e)).toList()] method, for any other types your want to translate to
  @override
  Future<List<T?>> list<T>({
    int? id,
    String? type,
    String? itemId,
    BoxerQueryOption? options,
    ModelTranslatorFromJson<T>? fromJson,
    bool isReThrow = false,
  }) async {
    try {
      BoxerQueryOption op = getOptions(id: id, type: type, itemId: itemId);
      op = options?.merge(op) ?? op;
      return await super.list<T>(options: op, fromJson: fromJson);
    } catch (e, s) {
      if (isReThrow) rethrow;
      BoxerLogger.e(TAG, '$tableName method [fetch] error: $e, $s');
    }
    return [];
  }

  /**
   * Subclass additional convenient methods. [id, type, itemId] relevant
   */

  Future<int> add({
    String? type,
    String? itemId,
    dynamic value,
    bool isReThrow = false,

    // translator that usually not necessary. important!!! Will do replace the outer map, not merge with addAll!!!
    WriteTranslator<dynamic>? translator,
  }) async {
    translator ??= (e, s) => {
          if (type != null) BoxCacheTable.kCOLUMN_ITEM_TYPE: type,
          if (itemId != null) BoxCacheTable.kCOLUMN_ITEM_ID: itemId,
        };
    try {
      return await mInsert<dynamic>(value, translator: translator);
    } catch (e, s) {
      if (isReThrow) rethrow;
      BoxerLogger.e(TAG, '$tableName method [add] error: $e, $s');
    }
    return -1;
  }

  Future<int> remove({
    int? id,
    String? type,
    String? itemId,
    BoxerQueryOption? options,
    bool isReThrow = false,
  }) async {
    try {
      BoxerQueryOption op = getOptions(id: id, type: type, itemId: itemId);
      op = options?.merge(op) ?? op;
      return await delete(options: op);
    } catch (e, s) {
      if (isReThrow) rethrow;
      BoxerLogger.e(TAG, '$tableName method [remove] error: $e, $s');
    }
    return 0;
  }

  Future<bool> exist({
    int? id,
    String? type,
    String? itemId,
    BoxerQueryOption? options,
    bool isReThrow = false,
  }) async {
    return (await get<dynamic>(id: id, type: type, itemId: itemId, options: options, isReThrow: isReThrow)) != null;
  }

  Future<T?> get<T>({
    int? id,
    String? type,
    String? itemId,
    BoxerQueryOption? options,
    ModelTranslatorFromJson<T>? fromJson,
    bool isReThrow = false,
  }) async {
    try {
      BoxerQueryOption op = getOptions(id: id, type: type, itemId: itemId);
      op = options?.merge(op) ?? op;
      return await one<T>(options: op, fromJson: fromJson);
    } catch (e, s) {
      if (isReThrow) rethrow;
      BoxerLogger.e(TAG, '$tableName method [get] error: $e, $s');
    }
    return null;
  }

  /// unlike [reset] method
  /// [set] method just update/add(if not existed) the [value] for specified [id]&[type]&[itemId] without [remove]
  Future<int> set({
    int? id,
    String? type,
    String? itemId,
    dynamic value,
    BoxerQueryOption? options,
    bool isReThrow = false,
  }) async {
    /// 1. if [id] == null && [itemId] != null, we will insert a new one if corresponding record not existed
    if (id == null && itemId != null) {
      if (!(await exist(type: type, itemId: itemId, options: options, isReThrow: isReThrow))) {
        Future<int> doAddIfNotExisted() async {
          if ((await exist(type: type, itemId: itemId, options: options, isReThrow: isReThrow))) return -1;
          return await add(type: type, itemId: itemId, value: value, isReThrow: isReThrow);
        }

        // prohibit adding so many same [itemId] records when multi async [add] calls at same time
        int insertedId = await CallLock.id('$type-$itemId').call<int>(() async => await doAddIfNotExisted());
        // if inserted successfully, just like the [modify] method return the inserted count 1.
        if (insertedId != -1) return 1;
      }
    }

    /// 2. just modify the existed record
    return await modify(id: id, type: type, itemId: itemId, value: value, options: options, isReThrow: isReThrow);
  }

  /// [modify] method just update the [value] for specified [id]&[type]&[itemId] existed item
  Future<int> modify({
    int? id,
    String? type,
    String? itemId,
    dynamic value,
    BoxerQueryOption? options,
    bool isReThrow = false,
  }) async {
    try {
      BoxerQueryOption op = getOptions(id: id, type: type, itemId: itemId);
      op = options?.merge(op) ?? op;
      return await mUpdate(value, options: op);
    } catch (e, s) {
      if (isReThrow) rethrow;
      BoxerLogger.e(TAG, '$tableName method [change] error: $e, $s');
    }
    return 0;
  }

  /// different from [add]/[set]/[modify] methods
  /// [reset] method is using BATCH mode, [remove] the same [id]&[type]&[itemId] item first, then [add] a new one
  Future<void> reset({
    int? id,
    String? type,
    String? itemId,
    dynamic value,
    bool isReThrow = false,

    // extra translator, usually not necessary
    WriteTranslator<dynamic>? translator,
  }) async {
    try {
      /* List<Object?>? result = */ await doBatch((clone) {
        clone as BoxCacheTable;
        clone.remove(id: id, type: type, itemId: itemId);
        clone.add(type: type, itemId: itemId, value: value, translator: translator);
      });
      // the batch result is [deleted_count, inserted_id]
    } catch (e, s) {
      if (isReThrow) rethrow;
      BoxerLogger.e(TAG, '$tableName method [set] error: $e, $s');
    }
  }

  /// [eliminate] is for convenient delete some older records if the number of records exceeds the limit
  Future<int?> eliminate({
    required int limit,
    String? type,
    BoxerQueryOption? options,
    bool isReThrow = false,
  }) async {
    try {
      BoxerQueryOption op = getOptions(id: null, type: type, itemId: null);
      op = options?.merge(op) ?? op;
      int size = await super.count(op) ?? 0;
      if (size <= limit) {
        /// no need to eliminate
        return 0;
      }
      int minID = (await minId(options: op)) ?? 0;
      int maxID = (await maxId(options: op)) ?? 0;
      int lessThan = (maxID - ((maxID - minID) ~/ 2)) + 1;
      BoxerQueryOption op1 = BoxerQueryOption.l(column: BoxCacheTable.kCOLUMN_ID, value: lessThan);
      op = BoxerQueryOption.merge([op, op1]);
      return await delete(options: op);
    } catch (e, s) {
      if (isReThrow) rethrow;
      BoxerLogger.e(TAG, '$tableName method [eliminate] error: $e, $s');
    }
    return 0;
  }

  /// Utilities Methods

  BoxerQueryOption getOptions({int? id, String? type, String? itemId}) {
    void addIfNotNull(List list, dynamic check, dynamic value) => check != null ? list.add(value) : null;
    List<String> columns = [];
    addIfNotNull(columns, id, BoxCacheTable.kCOLUMN_ID);
    addIfNotNull(columns, type, BoxCacheTable.kCOLUMN_ITEM_TYPE);
    addIfNotNull(columns, itemId, BoxCacheTable.kCOLUMN_ITEM_ID);
    List<Object?> values = [];
    addIfNotNull(values, id, id);
    addIfNotNull(values, type, type);
    addIfNotNull(values, itemId, itemId);
    if (columns.isEmpty || values.isEmpty) return BoxerQueryOption();
    return BoxerQueryOption.eq(columns: columns, values: values);
  }

  Future<int?> maxId({BoxerQueryOption? options}) async {
    Object? object = await selectMax(BoxCacheTable.kCOLUMN_ID, where: options?.where, whereArgs: options?.whereArgs);
    return (object is int) ? object : null;
  }

  Future<int?> minId({BoxerQueryOption? options}) async {
    Object? object = await selectMin(BoxCacheTable.kCOLUMN_ID, where: options?.where, whereArgs: options?.whereArgs);
    return (object is int) ? object : null;
  }
}
