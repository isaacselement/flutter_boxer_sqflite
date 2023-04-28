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

  /// equals
  factory BoxerQueryOption.e({required String column, required Object? value}) {
    return BoxerQueryOption.eq(columns: [column], values: [value]);
  }

  factory BoxerQueryOption.eq({required List<String> columns, required List<Object?> values}) {
    String _where = columns.map((e) => '$e  = ?').toList().join(' AND ');
    return BoxerQueryOption()
      ..where = _where
      ..whereArgs = values;
  }

  /// not equals
  factory BoxerQueryOption.ne({required String column, required Object? value}) {
    return BoxerQueryOption.neq(columns: [column], values: [value]);
  }

  factory BoxerQueryOption.neq({required List<String> columns, required List<Object?> values}) {
    String _where = columns.map((e) => '$e  != ?').toList().join(' AND '); // != or <> both ok
    return BoxerQueryOption()
      ..where = _where
      ..whereArgs = values;
  }

  /// less than
  factory BoxerQueryOption.l({required String column, required Object? value}) {
    return BoxerQueryOption.lt(columns: [column], values: [value]);
  }

  factory BoxerQueryOption.lt({required List<String> columns, required List<Object?> values}) {
    String _where = columns.map((e) => '$e  < ?').toList().join(' AND ');
    return BoxerQueryOption()
      ..where = _where
      ..whereArgs = values;
  }

  /// greater than
  factory BoxerQueryOption.g({required String column, required Object? value}) {
    return BoxerQueryOption.gt(columns: [column], values: [value]);
  }

  factory BoxerQueryOption.gt({required List<String> columns, required List<Object?> values}) {
    String _where = columns.map((e) => '$e  > ?').toList().join(' AND ');
    return BoxerQueryOption()
      ..where = _where
      ..whereArgs = values;
  }

  /// is null
  factory BoxerQueryOption.isNull({required String column}) {
    return BoxerQueryOption.isNulls(columns: [column]);
  }

  factory BoxerQueryOption.isNulls({required List<String> columns}) {
    String _where = columns.map((e) => '$e  is NULL').toList().join(' AND ');
    return BoxerQueryOption()..where = _where;
  }

  /// merge different where clause, only support where clause now
  factory BoxerQueryOption.merge(List<BoxerQueryOption> options) {
    List<String> wheres = [];
    List<Object?> values = [];
    options.forEach((e) {
      if (e.where != null) wheres.add(e.where!);
      if (e.whereArgs != null) values.addAll(e.whereArgs!);
    });
    return BoxerQueryOption()
      ..where = wheres.join(' AND ')
      ..whereArgs = values;
  }
}
