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

  static int currentUserId = 0; // empCode now, previous is uid

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

    queryAsObjectTranslator = (Map<String, Object?> element) {
      Object? value = element[kCOLUMN_ITEM_VALUE];

      /// TODO ... Decryption ...
      return value;
    };

    insertionTranslator = (dynamic item) {
      Object? value;
      if (item is num || item is String) {
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
      value ??= item.toString();

      /// TODO ... Encryption ...
      return {kCOLUMN_ITEM_VALUE: value};
    };
  }

  bool isRoleUnconcerned = false;

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

  BoxerQueryOption optionsWithUserRoleId(BoxerQueryOption options) {
    List<String> _where = ['$kCOLUMN_USER_ID = ?', '$kCOLUMN_ROLE_ID = ? '];
    List<Object?> _whereArgs = [currentUserId, currentRoleId];
    if (isRoleUnconcerned == true) {
      _where.removeLast();
      _whereArgs.removeLast();
    }
    if (options.where != null) _where.add(options.where!);
    if (options.whereArgs != null) _whereArgs.addAll(options.whereArgs!);
    options.where = _where.join(" AND ");
    options.whereArgs = _whereArgs;
    return options;
  }

  /// Subclass additional methods

  Future<String?> getOne({int? id, String? type, String? itemId, bool last = false}) async {
    List<String> list = await mQueryAsStrings(options: getOptions(id: id, type: type, itemId: itemId));
    return last ? list.lastSafe : list.firstSafe;
  }

  Future<Map?> getOneAsMap({int? id, String? type, String? itemId, bool last = false}) async {
    try {
      List<Map> list = await mQueryAsMap(options: getOptions(id: id, type: type, itemId: itemId));
      return last ? list.lastSafe : list.firstSafe;
    } catch (e, s) {
      BoxerLogger.e(TAG, '$tableName getOneAsMap error: $e, $s');
    }
    return null;
  }

  Future<int> remove({int? id, String? type, String? itemId}) async {
    return await delete(options: getOptions(id: id, type: type, itemId: itemId));
  }

  Future<List<Object?>?> eliminatedAdd({String? type, String? itemId, dynamic value}) async {
    // 清除相同 type 及 itemId 的，再添加，保证只有一个
    return await doBatch((clone) {
      clone as BoxCacheTable;
      clone.remove(type: type, itemId: itemId);
      clone.addOne(type: type, itemId: itemId, value: value);
    });
  }

  Future<int> addOne({String? type, String? itemId, dynamic value}) async {
    Map<String, Object?> values = insertionTranslator!(value);
    values.addAll({
      BoxCacheTable.kCOLUMN_ITEM_TYPE: type,
      BoxCacheTable.kCOLUMN_ITEM_ID: itemId,
    });
    return await insert(values);
  }

  Future<int> updateOne({String? type, String? itemId, dynamic value}) async {
    Map<String, Object?> values = insertionTranslator!(value);
    return await update(values, options: getOptions(type: type, itemId: itemId));
  }

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
