import 'dart:convert';
import 'dart:math';

import 'package:example/common/util/toast_helper.dart';
import 'package:example/common/util/widget_util.dart';
import 'package:example/database/box_cache_handler.dart';
import 'package:example/database/box_cache_table.dart';
import 'package:example/widget/table_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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

  BoxCacheTable get mTable => BoxCacheHandler.settingsTable;

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
                      await mTable.clear(); // care about the userId & roleId
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
                      BoxerLogger.d(TAG, '---->>>>> [query] outer result: ${results.length},  ${json.encode(results)}');
                    }),
                    action(Icons.one_k, '>>> [list] method', (Map action) async {
                      List<String?> results = await mTable.list<String>(
                        options: BoxerQueryOption.eM(map: {BoxCacheTable.kCOLUMN_ITEM_TYPE: 'IS_READ'}),
                      );
                      ToastHelper.show('[list] result count: ${results.length}');
                      BoxerLogger.d(TAG, '---->>>>> [list] result: ${results.length},  ${json.encode(results)}');
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
                  Future<String> getFirstItemId() async {
                    List<Map<String, Object?>> results = await mTable.query(
                      options: BoxerQueryOption.eM(map: {BoxCacheTable.kCOLUMN_ITEM_TYPE: 'IS_READ'}),
                    );
                    Map<String, Object?>? first = results.firstSafe;
                    if (first == null) {
                      ToastHelper.show('Query no result');
                    }
                    return first?[BoxCacheTable.kCOLUMN_ITEM_ID]?.toString() ?? '';
                  }

                  List<Map> sheet = [
                    action(Icons.one_k, '[add] method', (Map action) async {
                      int identifier = await mTable.add(type: 'IS_READ', itemId: StringsUtils.fakeUUID(), value: "1");
                      ToastHelper.show('[add] value: $identifier');
                    }),
                    action(Icons.one_k, '[remove] method', (Map action) async {
                      String _itemId = await getFirstItemId();
                      int value = await mTable.remove(type: 'IS_READ', itemId: _itemId);
                      ToastHelper.show('[remove] count: $value');
                    }),
                    action(Icons.one_k, '[get] method', (Map action) async {
                      String _itemId = await getFirstItemId();
                      String value = await mTable.get(type: 'IS_READ', itemId: _itemId);
                      ToastHelper.show('[get] value: $value');
                    }),
                    action(Icons.one_k, '[set] method', (Map action) async {
                      String _itemId = await getFirstItemId();
                      await mTable.set(type: 'IS_READ', itemId: _itemId, value: '${Random().nextInt(10) + 1}');
                    }),
                    action(Icons.one_k, '[modify] method', (Map action) async {
                      String _itemId = await getFirstItemId();
                      await mTable.modify(type: 'IS_READ', itemId: _itemId, value: '${Random().nextInt(10) + 10}');
                    }),
                    action(Icons.one_k, '[eliminate] method', (Map action) async {
                      await mTable.eliminate(
                        options: BoxerQueryOption.eM(map: {BoxCacheTable.kCOLUMN_ITEM_TYPE: 'IS_READ'}),
                        limit: 6,
                      );
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
                      int mId = await mTable.mInsert(true, translator: (e) {
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
                    action(Icons.one_k, 'Query num', (Map action) async {
                      BoxerQueryOption o1 =
                          BoxerQueryOption.eM(map: {BoxCacheTable.kCOLUMN_ITEM_TYPE: 'int_value_case'});
                      BoxerQueryOption o2 =
                          BoxerQueryOption.eM(map: {BoxCacheTable.kCOLUMN_ITEM_TYPE: 'double_value_case'});
                      BoxerQueryOption op = BoxerQueryOption.merge([o1, o2], join: BoxerOptionType.OR).group();
                      List<num?> results = await mTable.list<num>(options: op);
                      print('######## list results >>>>> $results');
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

  List<String>? columnNames = null;
  Map<String, dynamic> datasource = {};
  ScrollController? scrollController = null;

  Future<void> refreshTableViewDatasource() async {
    Database database = mTable.database;
    String tableName = mTable.tableName;
    columnNames ??= await BoxerDatabaseUtil.getColumnNamesRaw(database, tableName);
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
}
