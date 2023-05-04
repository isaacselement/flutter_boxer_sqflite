import 'dart:async';
import 'dart:convert';

import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';

class BizTableCache extends BoxerTableTranslator {
  static const String kCOLUMN_ID = 'ID';
  static const String kCOLUMN_TYPE = 'TYPE';
  static const String kCOLUMN_ITEM_ID = 'ITEM_ID';
  static const String kCOLUMN_ITEM_VALUE = 'ITEM_VALUE';
  static const String kCOLUMN_CREATE_TIME = 'CREATE_TIME';
  static const String kCOLUMN_UPDATE_TIME = 'UPDATE_TIME';
  static const String kCOLUMN_UID = 'UID';
  static const String kCOLUMN_ROLE_ID = 'ROLE_ID';

  static int currentUid = 0;
  static int currentRoleId = 0;

  static List<String> get commonSqlWhere => ['$kCOLUMN_UID = ?', '$kCOLUMN_ROLE_ID = ? '];

  static List<Object?> get commonSqlWhereArgs => [currentUid, currentRoleId];

  BizTableCache({required String tableName}) : super() {
    _tableName = tableName;

    insertionsBreakHandler = () async {
      // Limit the number of entries to a specified capacity to avoid infinite insertion
      int? capacity = 5000;
      if ((await selectCount() ?? 0) > capacity) {
        BxLoG.d('$tableName insert exceed limits capacity $capacity !');
        return true;
      }
      return false;
    };

    queryAsTranslator = (Map<String, Object?> element) {
      Object? value = element[kCOLUMN_ITEM_VALUE];

      /// TODO ... 解密 ...
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

      /// TODO ... 加密 ...
      return {kCOLUMN_ITEM_VALUE: value};
    };
  }

  late String _tableName;

  @override
  String get tableName => _tableName;

  @override
  String? get createTableSpecification => ''
      '$kCOLUMN_ID INTEGER PRIMARY KEY AUTOINCREMENT, '
      '$kCOLUMN_TYPE TEXT, '
      '$kCOLUMN_ITEM_ID TEXT, '
      '$kCOLUMN_ITEM_VALUE TEXT, '
      '$kCOLUMN_CREATE_TIME INTEGER, '
      '$kCOLUMN_UPDATE_TIME INTEGER, '
      '$kCOLUMN_UID INTEGER, '
      '$kCOLUMN_ROLE_ID INTEGER, '
      // extra create sql something like `CREATE INDEX ...`
      ';'
      'CREATE INDEX IF NOT EXISTS Idx_${kCOLUMN_ITEM_ID}_$tableName ON $tableName ( $kCOLUMN_ITEM_ID )';

  // 'CREATE UNIQUE INDEX IF NOT EXISTS Uq_${kCOLUMN_ITEM_ID}_$tableName ON $tableName ( $kCOLUMN_ITEM_ID )';

  @override
  BoxerTableBase? clone() => BizTableCache(tableName: this.tableName);

  @override
  void onQuery(BoxerQueryOption options) {
    appendOptionsWithUidRoleId(options);
  }

  @override
  void onDelete(BoxerQueryOption options) {
    appendOptionsWithUidRoleId(options);
  }

  @override
  void onInsertValues(Map<String, Object?> values) {
    values['$kCOLUMN_CREATE_TIME'] = DateTime.now().millisecondsSinceEpoch;
    values.addAll({kCOLUMN_UID: currentUid, kCOLUMN_ROLE_ID: currentRoleId});
  }

  @override
  void onUpdateValues(Map<String, Object?> values, BoxerQueryOption options) {
    values['$kCOLUMN_UPDATE_TIME'] = DateTime.now().millisecondsSinceEpoch;
    appendOptionsWithUidRoleId(options);
  }

  void appendOptionsWithUidRoleId(BoxerQueryOption options) {
    List<String> _where = List.from(commonSqlWhere);
    List<Object?> _whereArgs = List.from(commonSqlWhereArgs);
    if (options.where != null) _where.add(options.where!);
    if (options.whereArgs != null) _whereArgs.addAll(options.whereArgs!);
    options.where = _where.join(" AND ");
    options.whereArgs = _whereArgs;
  }

  /// Subclass additional methods

  Future<String?> getOne({int? id, String? type, String? itemId}) async {
    BoxerQueryOption options = BoxerQueryOption.eq(
      columns: [
        if (id != null) BizTableCache.kCOLUMN_ID,
        if (type != null) BizTableCache.kCOLUMN_TYPE,
        if (itemId != null) BizTableCache.kCOLUMN_ITEM_ID,
      ],
      values: [
        if (id != null) id,
        if (type != null) type,
        if (itemId != null) itemId,
      ],
    );
    return (await mQueryAsStrings(options: options)).firstSafe;
  }

  Future<int> addOne({String? type, String? itemId, dynamic value}) async {
    Map<String, Object?> values = {
      BizTableCache.kCOLUMN_TYPE: type,
      BizTableCache.kCOLUMN_ITEM_ID: itemId,
      BizTableCache.kCOLUMN_ITEM_VALUE: value,
    };
    return await insert(values);
  }

  Future<int?> maxId() async {
    Object? object = await selectMax(BizTableCache.kCOLUMN_ID);
    return (object is int) ? object : null;
  }

  Future<int?> minId() async {
    Object? object = await selectMin(BizTableCache.kCOLUMN_ID);
    return (object is int) ? object : null;
  }
}
