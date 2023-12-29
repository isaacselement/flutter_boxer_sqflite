import 'dart:convert';
import 'dart:math';

import 'package:example/common/util/toast_helper.dart';
import 'package:example/common/util/widget_util.dart';
import 'package:example/database/box_cache_handler.dart';
import 'package:example/database/box_cache_table.dart';
import 'package:example/widget/table_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_boxer_sqflite/core/features/boxer_query_functions.dart';
import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';
import 'package:flutter_dialog_shower/flutter_dialog_shower.dart';

class PageSettingsTable extends StatefulWidget {
  PageSettingsTable({Key? key}) : super(key: key);

  @override
  PageSettingsTableState createState() => PageSettingsTableState();
}

class PageSettingsTableState extends State<PageSettingsTable> with WidgetsBindingObserver {
  static const String TAG = 'PageSettingsTable';

  @override
  void initState() {
    super.initState();
    Boxes.getWidgetsBinding().addObserver(this);
    refreshTableViewDatasource();
  }

  @override
  void dispose() {
    Boxes.getWidgetsBinding().removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    setState(() {});
  }

  List<String>? columnNames = null;
  Map<String, dynamic> datasource = {};
  ScrollController? scrollController = null;

  Future<void> refreshTableViewDatasource() async {
    Database database = mTable.database;
    String tableName = mTable.tableName;
    columnNames ??= await BoxerDatabaseUtil.getColumnNames(database, tableName);
    scrollController ??= ScrollController();

    Map<String, dynamic>? map = {};
    List<dynamic> rowsResults = [];
    map[TableView.keyTblName] = tableName;
    map[TableView.keyTblColumns] = columnNames;
    map[TableView.keyTblRowCount] = rowsResults.length;
    map[TableView.keyTblRowResults] = rowsResults;
    datasource = map;
    if (mounted) {
      setState(() {});
    }

    () async {
      rowsResults = await database.query(tableName);
      map[TableView.keyTblRowCount] = rowsResults.length;
      map[TableView.keyTblRowResults] = rowsResults;
      if (mounted) {
        setState(() {});
      }
    }();
  }

  Widget createTableView() {
    Map<String, dynamic> map = datasource;
    if (map.isEmpty) return SizedBox();
    return TableView(
      tableName: map[TableView.keyTblName],
      columnNames: List<String>.from(map[TableView.keyTblColumns]),
      rowsCount: map[TableView.keyTblRowCount],
      rowsResults: List<Map<String, Object?>>.from(map[TableView.keyTblRowResults]),
      scrollController: scrollController,
      height: 600,
      isShowSeq: true,
    );
  }

  BoxCacheTable get mTable => BoxCacheHandler.settingsTable;

  BoxCacheTable? _globalSettingsTable;

  BoxCacheTable get globalSettingsTable => _globalSettingsTable ??= (mTable.cloneInstance as BoxCacheTable)
    ..isUserIdConcerned = false
    ..isRoleIdConcerned = false;

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> action(IconData i, String s, Function(Map m) f) {
      return WidgetUtil.actionSheetItem(i, s, (e) async {
        f(e);
        await Future.delayed(Duration(milliseconds: 200));
        refreshTableViewDatasource();
      });
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Wrap(
            children: [
              /**
               * Refresh
               */
              CupertinoButton(
                child: Text('Refresh', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () async {
                  refreshTableViewDatasource();
                },
              ),

              /**
               * Clear
               */
              CupertinoButton(
                child: Text('Clear', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () async {
                  List<Map> sheet = [
                    action(Icons.one_k, 'Clear force', (Map action) async {
                      await mTable.executor.delete(mTable.tableName);
                    }),
                    action(Icons.one_k, 'Clear self', (Map action) async {
                      await mTable.delete(); // care about the userId & roleId
                    }),
                    action(Icons.one_k, 'Reset auto id', (Map action) async {
                      await mTable.resetAutoId();
                    }),
                  ];
                  WidgetUtil.showActionSheet(sheet: sheet);
                },
              ),

              /**
               * Query & list
               */
              CupertinoButton(
                child: Text('Query', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () async {
                  List<Map> sheet = [
                    action(Icons.one_k, '>>> [query] method', (Map action) async {
                      List<Map<String, Object?>> results = await mTable.query(
                        options: BoxerQueryOption.eM(map: {BoxCacheTable.kCOLUMN_ITEM_TYPE: 'IS_READ'}),
                      );
                      ToastHelper.show('[query] result count: ${results.length}');
                      BoxerLogger.d(TAG,
                          '---->>>>> [query] outer result: ${results.length},  \nJSON string: ${json.encode(results)}');
                    }),
                    action(Icons.one_k, '>>> [list] method', (Map action) async {
                      List<String?> results = await mTable.list<String>(
                        options: BoxerQueryOption.eM(map: {BoxCacheTable.kCOLUMN_ITEM_TYPE: 'IS_READ'}),
                      );
                      ToastHelper.show('[list] result count: ${results.length}');
                      BoxerLogger.d(
                          TAG, '---->>>>> [list] result: ${results.length},  \nJSON string: ${json.encode(results)}');
                    }),
                    action(Icons.one_k, '>>> [select one] method', (Map action) async {
                      Object? results = await mTable.select([BoxCacheTable.kCOLUMN_ITEM_VALUE], isUnique: true);
                      ToastHelper.show('[select] result: ${results}');
                      BoxerLogger.d(TAG, '---->>>>> [select one] result: ${results}');
                    }),
                    action(Icons.one_k, '>>> [select two/true] method', (Map action) async {
                      Object? results = await mTable.select(
                        [BoxCacheTable.kCOLUMN_ITEM_TYPE, BoxCacheTable.kCOLUMN_ITEM_VALUE],
                        isUnique: true,
                      );
                      ToastHelper.show('[select two/true] result: ${results}');
                      BoxerLogger.d(
                          TAG, '---->>>>> [list two/true] result: ${results},  \nJSON string: ${json.encode(results)}');
                    }),
                    action(Icons.one_k, '>>> [select two/false] method', (Map action) async {
                      Object? results = await mTable.select(
                        [BoxCacheTable.kCOLUMN_ITEM_TYPE, BoxCacheTable.kCOLUMN_ITEM_VALUE],
                        isUnique: false,
                      );
                      ToastHelper.show('[select two/false] result: ${results}');
                      BoxerLogger.d(TAG,
                          '---->>>>> [list two/false] result: ${results},  \nJSON string: ${json.encode(results)}');
                    }),
                  ];
                  WidgetUtil.showActionSheet(sheet: sheet);
                },
              ),

              /**
               * Add & Remove & Get & Set & Modify
               */
              CupertinoButton(
                child: Text('Add & Get & Set & Modify & Remove ', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () async {
                  // common test item type
                  String itemType = 'IS_READ';

                  // func first item
                  Future<String> getFirstItemId({String type = 'IS_READ'}) async {
                    List<Map<String, Object?>> results = await mTable.query(
                      options: BoxerQueryOption.eM(map: {BoxCacheTable.kCOLUMN_ITEM_TYPE: type}),
                    );
                    Map<String, Object?>? first = results.firstSafe;
                    if (first == null) {
                      ToastHelper.show('Query no result');
                    }
                    return first?[BoxCacheTable.kCOLUMN_ITEM_ID]?.toString() ?? '';
                  }

                  List<Map> sheet = [
                    action(Icons.one_k, '[set] multi at same time', (Map action) async {
                      String sameItemId = StringsUtils.fakeUUID();
                      for (int i = 0; i < 10; i++) {
                        mTable.set(type: itemType, itemId: sameItemId, value: "$i").then((value) {
                          BoxerLogger.d('ToastHelper', '>>>>> set for new record, affect row count is: $value');
                        });
                      }
                    }),
                    action(Icons.one_k, '[exist] method', (Map action) async {
                      String _itemId = await getFirstItemId();
                      bool isExisted = await mTable.exist(type: itemType, itemId: _itemId);
                      bool fake = await mTable.exist(type: itemType, itemId: StringsUtils.fakeUUID());
                      ToastHelper.show('Is existed? $isExisted, fake existed? $fake');
                    }),
                    action(Icons.one_k, '[add] method for User', (Map action) async {
                      int identifier = await mTable.add(type: itemType, itemId: StringsUtils.fakeUUID(), value: "1");
                      ToastHelper.show('[add] value: $identifier');
                    }),
                    action(Icons.one_k, '[add] method for Global', (Map action) async {
                      int? identifier =
                          await globalSettingsTable.add(type: itemType, itemId: StringsUtils.fakeUUID(), value: "1");
                      ToastHelper.show('[add] value: $identifier');
                    }),
                    action(Icons.one_k, '[first] & [last] methods', (Map action) async {
                      String? firstValue = await mTable.first<String>(type: itemType);
                      String? lastValue = await mTable.last<String>(type: itemType);
                      ToastHelper.show('[first] value: $firstValue, [last] value: $lastValue');
                    }),
                    action(Icons.one_k, '[remove] method', (Map action) async {
                      String _itemId = await getFirstItemId();
                      int value = await mTable.remove(type: itemType, itemId: _itemId);
                      ToastHelper.show('[remove] count: $value');
                    }),
                    action(Icons.one_k, '[get] method', (Map action) async {
                      String _itemId = await getFirstItemId();
                      String value = await mTable.get(type: itemType, itemId: _itemId);
                      ToastHelper.show('[get] value: $value');
                    }),
                    action(Icons.one_k, '[set] method', (Map action) async {
                      String _itemId = await getFirstItemId();
                      int value = Random().nextInt(10) + 10;
                      ToastHelper.show('Value change to $value');
                      await mTable.set(type: itemType, itemId: _itemId, value: '$value');
                    }),
                    action(Icons.one_k, '[modify] method', (Map action) async {
                      String _itemId = await getFirstItemId();
                      int value = Random().nextInt(10) + 10;
                      ToastHelper.show('Value change to $value');
                      await mTable.modify(type: itemType, itemId: _itemId, value: '$value');
                    }),
                    action(Icons.one_k, '[reset] method', (Map action) async {
                      String _itemId = await getFirstItemId();
                      int value = Random().nextInt(10) + 10;
                      ToastHelper.show('Value change to $value');
                      await mTable.reset(type: itemType, itemId: _itemId, value: '$value');
                    }),
                    action(Icons.one_k, '[eliminate] method, (6)', (Map action) async {
                      await mTable.eliminate(limit: 6, type: itemType);
                    }),
                  ];
                  WidgetUtil.showActionSheet(sheet: sheet);
                },
              ),

              /**
               * Insert & Query num/int/double/bool type value
               */
              CupertinoButton(
                child: Text('Primitive Type', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () async {
                  List<Map> sheet = [
                    action(Icons.one_k, 'Insert bool', (Map action) async {
                      int mId = await mTable.mInsert(new Random().nextBool(), translator: (e) {
                        return {BoxCacheTable.kCOLUMN_ITEM_TYPE: 'bool_value_case'};
                      });
                      print('######## mInserted id >>>>> $mId');

                      BoxerQueryOption op =
                          BoxerQueryOption.eM(map: {BoxCacheTable.kCOLUMN_ITEM_TYPE: 'bool_value_case'});
                      List<bool?> results = await mTable.list<bool>(options: op);
                      print('######## list results >>>>> $results');
                    }),
                    action(Icons.one_k, 'Insert int', (Map action) async {
                      int mId = await mTable.mInsert(100, translator: (e) {
                        return {BoxCacheTable.kCOLUMN_ITEM_TYPE: 'int_value_case'};
                      });
                      print('######## mInserted id >>>>> $mId');

                      BoxerQueryOption op =
                          BoxerQueryOption.eM(map: {BoxCacheTable.kCOLUMN_ITEM_TYPE: 'int_value_case'});
                      List<int?> results = await mTable.list<int>(options: op);
                      print('######## list results >>>>> $results');
                    }),
                    action(Icons.one_k, 'Insert double', (Map action) async {
                      int mId = await mTable.mInsert(121.01, translator: (e) {
                        return {BoxCacheTable.kCOLUMN_ITEM_TYPE: 'double_value_case'};
                      });
                      print('######## mInserted id >>>>> $mId');

                      BoxerQueryOption op =
                          BoxerQueryOption.eM(map: {BoxCacheTable.kCOLUMN_ITEM_TYPE: 'double_value_case'});
                      List<double?> results = await mTable.list<double>(options: op);
                      print('######## list results >>>>> $results');
                    }),
                    action(Icons.one_k, 'Query all num', (Map action) async {
                      BoxerQueryOption o1 =
                          BoxerQueryOption.eM(map: {BoxCacheTable.kCOLUMN_ITEM_TYPE: 'int_value_case'});
                      BoxerQueryOption o2 =
                          BoxerQueryOption.eM(map: {BoxCacheTable.kCOLUMN_ITEM_TYPE: 'double_value_case'});
                      BoxerQueryOption o = BoxerQueryOption.merge([o1, o2], join: BoxerOptionType.OR).group();
                      List<num?> results = await mTable.list<num>(options: o);
                      print('######## list results >>>>> $results');
                      ToastHelper.show('All num values $results');
                    }),
                    action(Icons.one_k, 'Query all primitive [fetch]', (Map action) async {
                      dynamic valueToNumOrBool(e) {
                        dynamic v = num.tryParse(e?.toString() ?? '');
                        if (v == null) {
                          v = BoxerQueryFunctions.toBool(e);
                        }
                        return v;
                      }

                      BoxerQueryOption o2 = mTable.getOptions(type: 'int_value_case');
                      BoxerQueryOption o3 = mTable.getOptions(type: 'double_value_case');
                      BoxerQueryOption o1 = mTable.getOptions(type: 'bool_value_case');

                      BoxerQueryOption o =
                          o1.merge(o2, join: BoxerOptionType.OR).merge(o3, join: BoxerOptionType.OR).group();
                      List<dynamic> results = (await mTable.list<dynamic>(options: o)).map(valueToNumOrBool).toList();
                      print('######## list results >>>>> $results');
                      ToastHelper.show('All primitive values $results');
                    }),
                    action(Icons.one_k, 'Query all primitive [query]', (Map action) async {
                      dynamic mapToNumOrBool(e) {
                        if (e is Map) {
                          String? value = e[BoxCacheTable.kCOLUMN_ITEM_VALUE];
                          String? type = e[BoxCacheTable.kCOLUMN_ITEM_TYPE];
                          if (type == 'bool_value_case') {
                            return BoxerQueryFunctions.toBool(value);
                          } else if (type == 'int_value_case' || type == 'double_value_case') {
                            return num.tryParse(value ?? '');
                          }
                        }
                        return null;
                      }

                      BoxerQueryOption o2 = mTable.getOptions(type: 'int_value_case');
                      BoxerQueryOption o3 = mTable.getOptions(type: 'double_value_case');
                      BoxerQueryOption o1 = mTable.getOptions(type: 'bool_value_case');

                      BoxerQueryOption o =
                          o1.merge(o2, join: BoxerOptionType.OR).merge(o3, join: BoxerOptionType.OR).group();
                      // or pass a not null translator to [mQuery], will not use the default translator you've set.
                      List<Object?> results = (await mTable.query(options: o)).map(mapToNumOrBool).toList();
                      print('######## list results >>>>> $results');
                      ToastHelper.show('All primitive values $results');
                    }),
                  ];
                  WidgetUtil.showActionSheet(sheet: sheet);
                },
              ),
            ],
          ),
          // table view
          createTableView(),
        ],
      ),
    );
  }
}
