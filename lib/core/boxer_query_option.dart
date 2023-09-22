import 'package:flutter_boxer_sqflite/util/boxer_extensions.dart';

/// Class of holding the query/where sql parameters
class BoxerQueryOption {
  bool? distinct;
  List<String>? columns;
  String? where;
  List<Object?>? whereArgs;
  String? groupBy;
  String? having;
  String? orderBy;
  int? limit;
  int? offset;

  BoxerQueryOption();

  BoxerQueryOption reset({BoxerQueryOption? option}) {
    distinct = option?.distinct;
    columns = option?.columns;
    where = option?.where;
    whereArgs = option?.whereArgs;
    groupBy = option?.groupBy;
    having = option?.having;
    orderBy = option?.orderBy;
    limit = option?.limit;
    offset = option?.offset;
    return this;
  }

  BoxerQueryOption clone() {
    BoxerQueryOption newOp = BoxerQueryOption();
    newOp.distinct = this.distinct;
    newOp.columns = this.columns;
    newOp.where = this.where;
    newOp.whereArgs = this.whereArgs;
    newOp.groupBy = this.groupBy;
    newOp.having = this.having;
    newOp.orderBy = this.orderBy;
    newOp.limit = this.limit;
    newOp.offset = this.offset;
    return newOp;
  }

  BoxerQueryOption group() {
    String? _where = where;
    if (_where != null && (_where = _where.trim()).isNotEmpty) {
      where = ' ( $where ) ';
    }
    return this;
  }

  BoxerQueryOption merge(
    BoxerQueryOption? option, {
    BoxerOptionType join = BoxerOptionType.AND,
  }) {
    if (option == null) return this.clone();
    return BoxerQueryOption.merge([this, option], join: join);
  }

  void insert({
    String? where,
    List<Object?>? whereArgs,
    BoxerOptionType join = BoxerOptionType.AND,
    bool isInsertInFront = false,
  }) {
    if (where == null || (where = where.trim()).isEmpty) return;

    /// insert where
    String? _where = this.where;
    if (_where == null || (_where = _where.trim()).isEmpty) {
      this.where = where;
    } else {
      this.where = joinWith(isInsertInFront ? [where, _where] : [_where, where], join);
    }

    /// insert where arguments
    if (whereArgs != null && whereArgs.isNotEmpty) {
      List<Object?> _whereArgs = List<Object?>.from(this.whereArgs ??= []);
      isInsertInFront ? _whereArgs.insertAll(0, whereArgs) : _whereArgs.addAll(whereArgs);
      this.whereArgs = _whereArgs;
    }
  }

  /// equals
  factory BoxerQueryOption.e({required String column, required Object? value}) {
    return BoxerQueryOption.eq(columns: [column], values: [value]);
  }

  factory BoxerQueryOption.eq({
    required List<String> columns,
    required List<Object?> values,
    BoxerOptionType join = BoxerOptionType.AND,
  }) {
    ensureLegality(columns: columns, values: values);
    String? _where = joinWith(columns.map((e) => '$e = ?').toList(), join);
    return BoxerQueryOption()
      ..where = _where
      ..whereArgs = values;
  }

  factory BoxerQueryOption.eM({
    required Map<String, dynamic> map,
    BoxerOptionType join = BoxerOptionType.AND,
  }) {
    List<String> columns = map.keys.toList();
    List<Object?> values = map.values.toList();
    return BoxerQueryOption.eq(columns: columns, values: values, join: join);
  }

  /// not equals
  factory BoxerQueryOption.n({required String column, required Object? value}) {
    return BoxerQueryOption.ne(columns: [column], values: [value]);
  }

  factory BoxerQueryOption.ne({
    required List<String> columns,
    required List<Object?> values,
    BoxerOptionType join = BoxerOptionType.AND,
  }) {
    ensureLegality(columns: columns, values: values);
    // != , <> both ok
    String? _where = joinWith(columns.map((e) => '$e != ?').toList(), join);
    return BoxerQueryOption()
      ..where = _where
      ..whereArgs = values;
  }

  factory BoxerQueryOption.nM({
    required Map<String, dynamic> map,
    BoxerOptionType join = BoxerOptionType.AND,
  }) {
    List<String> columns = map.keys.toList();
    List<Object?> values = map.values.toList();
    return BoxerQueryOption.ne(columns: columns, values: values, join: join);
  }

  /// less than
  factory BoxerQueryOption.l({required String column, required Object? value}) {
    return BoxerQueryOption.lt(columns: [column], values: [value]);
  }

  factory BoxerQueryOption.lt({
    required List<String> columns,
    required List<Object?> values,
    BoxerOptionType join = BoxerOptionType.AND,
  }) {
    ensureLegality(columns: columns, values: values);
    String? _where = joinWith(columns.map((e) => '$e < ?').toList(), join);
    return BoxerQueryOption()
      ..where = _where
      ..whereArgs = values;
  }

  factory BoxerQueryOption.lM({
    required Map<String, dynamic> map,
    BoxerOptionType join = BoxerOptionType.AND,
  }) {
    List<String> columns = map.keys.toList();
    List<Object?> values = map.values.toList();
    return BoxerQueryOption.lt(columns: columns, values: values, join: join);
  }

  /// greater than
  factory BoxerQueryOption.g({required String column, required Object? value}) {
    return BoxerQueryOption.gt(columns: [column], values: [value]);
  }

  factory BoxerQueryOption.gt({
    required List<String> columns,
    required List<Object?> values,
    BoxerOptionType join = BoxerOptionType.AND,
  }) {
    ensureLegality(columns: columns, values: values);
    String? _where = joinWith(columns.map((e) => '$e > ?').toList(), join);
    return BoxerQueryOption()
      ..where = _where
      ..whereArgs = values;
  }

  factory BoxerQueryOption.gM({
    required Map<String, dynamic> map,
    BoxerOptionType join = BoxerOptionType.AND,
  }) {
    List<String> columns = map.keys.toList();
    List<Object?> values = map.values.toList();
    return BoxerQueryOption.gt(columns: columns, values: values, join: join);
  }

  /// is null
  factory BoxerQueryOption.isNull({required String column}) {
    return BoxerQueryOption.isNulls(columns: [column]);
  }

  factory BoxerQueryOption.isNulls({
    required List<String> columns,
    BoxerOptionType join = BoxerOptionType.AND,
  }) {
    String? _where = joinWith(columns.map((e) => '$e IS NULL').toList(), join);
    return BoxerQueryOption()..where = _where;
  }

  /// like
  factory BoxerQueryOption.like({required String column, required Object? value}) {
    return BoxerQueryOption.likes(columns: [column], values: [value]);
  }

  factory BoxerQueryOption.likes({
    required List<String> columns,
    required List<Object?> values,
    BoxerOptionType join = BoxerOptionType.AND,
  }) {
    ensureLegality(columns: columns, values: values);
    String? _where = joinWith(columns.map((e) => '$e LIKE ?').toList(), join);
    return BoxerQueryOption()
      ..where = _where
      ..whereArgs = values;
  }

  /// [Attention] `groupBy` `having` `limit` `offset` are implemented by [merge]
  factory BoxerQueryOption.merge(
    List<BoxerQueryOption> options, {
    BoxerOptionType join = BoxerOptionType.AND,
  }) {
    bool? distinct;
    List<String> columns = [];
    List<String> wheres = [];
    List<Object?> whereArgs = [];
    List<String> orderBys = [];
    options.forEach((e) {
      // use the last one
      if (e.distinct != null) distinct = e.distinct;

      /// columns
      if (e.columns != null) columns.addAll(e.columns!);

      /// where and whereArgs
      String? _where = e.where;
      if (_where != null && (_where = _where.trim()).isNotEmpty) {
        wheres.add(_where);
        // Important: u may ensure that the 'whereArgs' is not null, and its length is equal with 'where' clause
        if (e.whereArgs != null) whereArgs.addAll(e.whereArgs!);
      }

      /// orderBy
      String? _orderBy = e.orderBy;
      if (_orderBy != null && (_orderBy = _orderBy.trim()).isNotEmpty) {
        orderBys.add(_orderBy);
      }
    });

    /// use the first one as the clone template
    BoxerQueryOption newOp = options.firstSafe?.clone() ?? BoxerQueryOption();
    String? _where = joinWith(wheres, join);
    List<Object?>? _whereArgs = whereArgs.isEmpty ? null : whereArgs;

    /// assign the merge value to the new option obj
    newOp.where = _where;
    newOp.whereArgs = _whereArgs;
    if (columns.isNotEmpty) {
      newOp.columns = columns;
    }
    if (orderBys.isNotEmpty) {
      newOp.orderBy = orderBys.join(", ");
    }

    newOp.distinct = distinct;

    /// TODO ... groupBy MERGE NOT IMPLEMENTATION
    /// TODO ... having MERGE NOT IMPLEMENTATION
    /// TODO ... limit MERGE NOT IMPLEMENTATION, WHICH ONE TO USE?
    /// TODO ... offset MERGE NOT IMPLEMENTATION, WHICH ONE TO USE?
    return newOp;
  }

  /// Utils

  static bool ensureLegality({required List<String> columns, required List<Object?> values}) {
    assert(columns.length == values.length, '[BoxerOptions] ERROR: column & value size not the same!');
    List<String> copy = List<String>.from(columns);
    copy.removeWhere((e) => e.trim().isEmpty);
    assert(columns.length == copy.length, '[BoxerOptions] ERROR: column list contains empty string!');
    bool illegal = columns.length != values.length || columns.length != copy.length;

    // remove the empty column and corresponding value
    List<String> temp = List<String>.from(columns);
    for (int i = temp.length - 1; i >= 0; i--) {
      if (temp[i].trim().isEmpty) {
        columns.remove(i);
        values.remove(i);
      }
    }
    return illegal;
  }

  static String? joinWith(List<String> list, BoxerOptionType type) {
    String where = list.join(optionTypeToString(type));
    return where.trim().isEmpty ? null : where;
  }

  static String optionTypeToString(BoxerOptionType type) {
    if (type == BoxerOptionType.AND) {
      return ' AND ';
    } else {
      return ' OR ';
    }
  }
}

enum BoxerOptionType { AND, OR }
