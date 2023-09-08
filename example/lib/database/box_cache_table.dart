import 'dart:async';
import 'dart:convert';

import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';

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

    writeTranslator = (dynamic item) {
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
      // extra create sql something like `CREATE INDEX ...`
      ';'
      // 'CREATE UNIQUE INDEX IF NOT EXISTS Uq_${kCOLUMN_ITEM_ID}_$tableName ON $tableName ( $kCOLUMN_ITEM_ID )';
      'CREATE INDEX IF NOT EXISTS Idx_${kCOLUMN_ITEM_ID}_$tableName ON $tableName ( $kCOLUMN_ITEM_ID )';

  @override
  BoxerTableBase? clone() => BoxCacheTable(tableName: this.tableName);

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
    values.addAll({kCOLUMN_USER_ID: currentUserId, kCOLUMN_ROLE_ID: currentRoleId});
  }

  @override
  void onUpdateValues(Map<String, Object?> values, BoxerQueryOption options) {
    values['$kCOLUMN_UPDATE_TIME'] = DateTime.now().millisecondsSinceEpoch;
    optionsWithUserRoleId(options);
  }

  bool isRoleUnconcerned = false;

  BoxerQueryOption optionsWithUserRoleId(BoxerQueryOption options) {
    BoxerQueryOption op = BoxerQueryOption.e(column: kCOLUMN_USER_ID, value: currentUserId);
    if (isRoleUnconcerned == false) {
      op = op.merge(BoxerQueryOption.e(column: kCOLUMN_ROLE_ID, value: currentRoleId)).group();
    }
    op = op.merge(options);
    options.set(op);
    return options;
  }

  /// Override query methods

  @override
  Future<T?> one<T>({
    BoxerQueryOption? options,
    ModelTranslatorFromJson<T>? fromJson,
    bool isReThrow = false,
  }) async {
    try {
      return await super.one<T>(options: options, fromJson: fromJson);
    } catch (e, s) {
      if (isReThrow) rethrow;
      BoxerLogger.e(TAG, '$tableName method [one] error: $e, $s');
    }
    return null;
  }

  @override
  Future<List<T?>> list<T>({
    BoxerQueryOption? options,
    ModelTranslatorFromJson<T>? fromJson,
    bool isReThrow = false,
  }) async {
    try {
      return await super.list<T>(options: options, fromJson: fromJson);
    } catch (e, s) {
      if (isReThrow) rethrow;
      BoxerLogger.e(TAG, '$tableName method [list] error: $e, $s');
    }
    return [];
  }

  /// Subclass additional methods.  [id, type, itemId] relevant

  Future<int> add({
    String? type,
    String? itemId,
    dynamic value,
    bool isReThrow = false,
  }) async {
    try {
      return await mInsert(value, translator: (e) {
        return {
          BoxCacheTable.kCOLUMN_ITEM_TYPE: type,
          BoxCacheTable.kCOLUMN_ITEM_ID: itemId,
        };
      });
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
    bool isReThrow = false,
  }) async {
    try {
      return await delete(options: getOptions(id: id, type: type, itemId: itemId));
    } catch (e, s) {
      if (isReThrow) rethrow;
      BoxerLogger.e(TAG, '$tableName method [remove] error: $e, $s');
    }
    return 0;
  }

  Future<T?> get<T>({
    int? id,
    String? type,
    String? itemId,
    ModelTranslatorFromJson<T>? fromJson,
    bool isReThrow = false,
  }) async {
    try {
      return await one<T>(options: getOptions(id: id, type: type, itemId: itemId), fromJson: fromJson);
    } catch (e, s) {
      if (isReThrow) rethrow;
      BoxerLogger.e(TAG, '$tableName method [get] error: $e, $s');
    }
    return null;
  }

  /// [set] is using BATCH mode, [remove] the same type and itemId, then [add] the new one
  Future<void> set({
    String? type,
    String? itemId,
    dynamic value,
    bool isReThrow = false,
  }) async {
    try {
      List<Object?>? result = await doBatch((clone) {
        clone as BoxCacheTable;
        clone.remove(type: type, itemId: itemId);
        clone.add(type: type, itemId: itemId, value: value);
      });

      /// TODO ... check out the result ~~~
    } catch (e, s) {
      if (isReThrow) rethrow;
      BoxerLogger.e(TAG, '$tableName method [set] error: $e, $s');
    }
  }

  /// unlike [set] method, [modify] just update the [value] for specified [id] / [type] / [itemId]
  Future<int> modify({
    int? id,
    String? type,
    String? itemId,
    dynamic value,
    bool isReThrow = false,
  }) async {
    try {
      return await mUpdate(value, options: getOptions(id: id, type: type, itemId: itemId));
    } catch (e, s) {
      if (isReThrow) rethrow;
      BoxerLogger.e(TAG, '$tableName method [change] error: $e, $s');
    }
    return 0;
  }

  /// [eliminate] is for convenient delete some older records if the number of records exceeds the limit
  Future<int?> eliminate({
    required BoxerQueryOption options,
    required int limit,
    bool isReThrow = false,
  }) async {
    try {
      int size = await super.count(options) ?? 0;
      if (size > limit) {
        int minID = (await minId()) ?? 0;
        int maxID = (await maxId()) ?? 0;
        int lessThan = (maxID - (maxID - minID) ~/ 2) + 1;
        BoxerQueryOption op = BoxerQueryOption.l(column: BoxCacheTable.kCOLUMN_ID, value: lessThan);
        options = BoxerQueryOption.merge([options, op]);
      }
      return await clear(options);
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
    List<String> values = [];
    addIfNotNull(values, id, id);
    addIfNotNull(values, type, type);
    addIfNotNull(values, itemId, itemId);
    if (columns.isEmpty || values.isEmpty) return BoxerQueryOption();
    return BoxerQueryOption.eq(columns: columns, values: values);
  }

  Future<int?> maxId() async {
    Object? object = await selectMax(BoxCacheTable.kCOLUMN_ID);
    return (object is int) ? object : null;
  }

  Future<int?> minId() async {
    Object? object = await selectMin(BoxCacheTable.kCOLUMN_ID);
    return (object is int) ? object : null;
  }
}
