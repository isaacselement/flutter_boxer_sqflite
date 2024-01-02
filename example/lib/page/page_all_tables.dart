import 'dart:convert';
import 'dart:math';

import 'package:example/common/util/dates_utils.dart';
import 'package:example/common/util/toast_helper.dart';
import 'package:example/common/util/widget_util.dart';
import 'package:example/database/box_cache_handler.dart';
import 'package:example/database/box_cache_table.dart';
import 'package:example/database/box_database_manager.dart';
import 'package:example/model/bread.dart';
import 'package:example/model/bread_api.dart';
import 'package:example/widget/table_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';
import 'package:flutter_dialog_shower/flutter_dialog_shower.dart';
import 'package:synchronized_call/synchronized_call.dart';

class PageAllTables extends StatefulWidget {
  PageAllTables({Key? key}) : super(key: key);

  @override
  PageAllTablesState createState() => PageAllTablesState();
}

class PageAllTablesState extends State<PageAllTables> with WidgetsBindingObserver {
  static const String TAG = 'PageAllTables';

  Widget allTableWidgets = Column();

  @override
  void initState() {
    super.initState();
    Boxes.getWidgetsBinding().addObserver(this);

    BoxCacheTable.currentUserId = 110;
    BoxCacheTable.currentRoleId = 10086;

    refresh();
  }

  @override
  void dispose() {
    Boxes.getWidgetsBinding().removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    refreshWholeTablesUIOnly();
  }

  Future<void> refresh() async {
    await refreshDataSource();
    refreshWholeTablesUIOnly();
  }

  List<Map<String, dynamic>> datasource = [];

  Future<void> refreshDataSource() async {
    await CallLock.get('refresh_datasource').call(() async => await _refreshDataSourceRaw());
  }

  Future<void> _refreshDataSourceRaw() async {
    await BoxDatabaseManager.init();
    datasource.clear();

    /// 1. normal tables we created, including sqlite_sequence
    await BoxDatabaseManager.boxer.iterateAllTables((tableName, columns) async {
      Map<String, dynamic>? map = {};
      List<Map<String, Object?>> rowsResults = await BoxDatabaseManager.boxer.database.query(tableName);
      map[TableView.keyTblName] = tableName;
      map[TableView.keyTblColumns] = columns;
      map[TableView.keyTblRowCount] = rowsResults.length;
      map[TableView.keyTblRowResults] = rowsResults;

      datasource.add(map);
      return false;
    });

    /// 2. sqlite_master
    String tableName = 'sqlite_master';
    String sql = "SELECT * FROM $tableName";
    List<String> columns = ['type', 'name', 'tbl_name', 'rootpage', 'sql'];

    Map<String, dynamic>? map = {};
    List<Map<String, Object?>> rowsResults = await BoxDatabaseManager.boxer.database.rawQuery(sql);
    map[TableView.keyTblName] = tableName;
    map[TableView.keyTblColumns] = columns;
    map[TableView.keyTblRowCount] = rowsResults.length;
    map[TableView.keyTblRowResults] = rowsResults;

    datasource.add(map);

    datasource.sort((a, b) {
      String an = a[TableView.keyTblName] ?? '';
      String bn = b[TableView.keyTblName] ?? '';
      if (an == BoxCacheHandler.commonTable.tableName) return -1;
      if (an == 'sqlite_sequence') return 1;
      if (an == 'sqlite_master') return 1;
      return an.compareTo(bn);
    });
  }

  Map<String, ScrollController> tableListScrollControllerMap = {};

  Future<void> refreshWholeTablesUIOnly() async {
    List<Widget> children = [];

    /// 1.
    for (int i = 0; i < datasource.length; i++) {
      Map<String, dynamic> map = datasource[i];
      String tableName = map[TableView.keyTblName];

      /// create table view
      Widget tableView = TableView(
        tableName: tableName,
        columnNames: List<String>.from(map[TableView.keyTblColumns]),
        rowsCount: map[TableView.keyTblRowCount],
        rowsResults: List<Map<String, Object?>>.from(map[TableView.keyTblRowResults]),
        scrollController: tableListScrollControllerMap[tableName] ??= ScrollController(),
      );

      /// append expand & collapse feature
      Widget collapseWidget = WidgetUtil.createExpandableWidget(
        child: tableView,
        expandText: 'Expand $tableName',
        collapseText: 'Collapse $tableName',
      );

      children.add(collapseWidget);
    }

    /// 2.
    children.add(SizedBox(height: 38));
    allTableWidgets = Column(children: children);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Wrap(
            children: [
              /**
               * Logs
               */
              CupertinoButton(
                child: const Text('Logs', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () async {
                  List<Map> sheet = [
                    WidgetUtil.actionSheetItem(Icons.one_k, 'Logger tests', (Map action) async {
                      BoxerLogger.logger = (int level, String? tag, String message) {
                        print('>>>>><<<<< logger: $level, $tag, $message');
                      };
                      BoxerLogger.v(null, 'v message');
                      BoxerLogger.d(null, 'd message');
                      BoxerLogger.i(null, 'i message');
                      BoxerLogger.logger = null;
                      BoxerLogger.w(null, 'w message');
                      BoxerLogger.f('TAG', 'f message');
                      BoxerLogger.marker = (int flag, String? tag, Object? object) {
                        BoxerLogger.d('marker', 'marker: $flag, $tag, $object');
                      };
                      BoxerLogger.mark(flag: 20001, tag: 'HAHA', object: '哈哈哈 data');
                      BoxerLogger.fatalReporter = (dynamic e, dynamic s) {
                        BoxerLogger.d('fatalReporter', 'fatalReporter: $e, $s');
                      };
                      BoxerLogger.reportFatal(AssertionError('You so good'), StackTrace.current);

                      BoxerLogger.console(() => 'console good job');
                    }),
                  ];

                  WidgetUtil.showActionSheet(sheet: sheet);
                },
              ),

              /**
               * Refresh
               */
              CupertinoButton(
                child: const Text('Refresh', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () async {
                  refreshDataSourceWithScrollToBottom();
                },
              ),

              /**
               * Utils
               */
              CupertinoButton(
                child: const Text('Utils', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () async {
                  List<Map> sheet = [
                    WidgetUtil.actionSheetItem(Icons.one_k, 'Get column value', (Map action) async {
                      List<Map<String, Object?>> values = await BoxCacheHandler.commonTable.query();
                      Map<String, Object?>? first = values.firstSafe;
                      BoxerQueryOption op =
                          BoxerQueryOption.e(column: BoxCacheTable.kCOLUMN_ID, value: first?[BoxCacheTable.kCOLUMN_ID]);
                      Object? itemId =
                          await BoxCacheHandler.commonTable.getColumnValue(BoxCacheTable.kCOLUMN_ITEM_ID, options: op);
                      ToastHelper.show('Get column value: $itemId');
                    }),
                    WidgetUtil.actionSheetItem(Icons.one_k, 'Set column value', (Map action) async {
                      Object? id = await BoxCacheHandler.commonTable.getColumnValue(BoxCacheTable.kCOLUMN_ID);
                      BoxerQueryOption op = BoxerQueryOption.e(column: BoxCacheTable.kCOLUMN_ID, value: id);
                      String value = '💯 [${Random().nextInt(100) + 1000}]';
                      await BoxCacheHandler.commonTable
                          .setColumnValue(BoxCacheTable.kCOLUMN_ITEM_ID, value, options: op);
                      ToastHelper.show('Set column id $id, value to: $value');
                      refreshDataSourceWithScrollToBottom();
                    }),
                  ];

                  WidgetUtil.showActionSheet(sheet: sheet);
                },
              ),

              /**
               * Clear
               */
              CupertinoButton(
                child: const Text('Clear', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () async {
                  List<Map> sheet = [
                    WidgetUtil.actionSheetItem(Icons.one_k, 'Clear force', (Map action) async {
                      await BoxCacheHandler.commonTable.executor.delete(BoxCacheHandler.commonTable.tableName);
                      refreshDataSourceWithScrollToBottom(BoxCacheHandler.commonTable.tableName);
                    }),
                    WidgetUtil.actionSheetItem(Icons.one_k, 'Clear self', (Map action) async {
                      await BoxCacheHandler.commonTable.delete(); // care about the userId & roleId
                      refreshDataSourceWithScrollToBottom(BoxCacheHandler.commonTable.tableName);
                    }),
                    WidgetUtil.actionSheetItem(Icons.one_k, 'Reset auto id', (Map action) async {
                      await BoxCacheHandler.commonTable.resetAutoId();
                      refreshDataSourceWithScrollToBottom(BoxCacheHandler.commonTable.tableName);
                    }),
                  ];
                  WidgetUtil.showActionSheet(sheet: sheet);
                },
              ),

              /**
               * Insert
               */
              CupertinoButton(
                child: const Text('Insert', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () async {
                  List<Map> sheet = [
                    WidgetUtil.actionSheetItem(Icons.one_k, 'Insert Bread Model [nothing]', (Map action) async {
                      int insertedId = await BoxCacheHandler.commonTable.mInsertModel<Bread>(BreadGenerator.oneModel);
                      refreshDataSourceWithScrollToBottom(BoxCacheHandler.commonTable.tableName);
                      BoxerLogger.d(TAG, '--------->>>>> inserted Bread Model id: $insertedId');
                    }),
                    WidgetUtil.actionSheetItem(Icons.one_k, 'Insert Bread Model [headline]', (Map action) async {
                      int insertedId = await BoxCacheHandler.commonTable.mInsertModel<Bread>(
                        BreadGenerator.oneModel,
                        translator: (e, s) => {
                          BoxCacheTable.kCOLUMN_ITEM_TYPE: 'BREAD_headline',
                        },
                      );
                      refreshDataSourceWithScrollToBottom(BoxCacheHandler.commonTable.tableName);
                      BoxerLogger.d(TAG, '--------->>>>> inserted Bread Model [headline] id: $insertedId');
                    }),
                    WidgetUtil.actionSheetItem(Icons.one_k, 'Insert Bread Model [newest]', (Map action) async {
                      int insertedId = await BoxCacheHandler.commonTable.mInsertModel<Bread>(
                        BreadGenerator.oneModel,
                        translator: (e, s) => {
                          BoxCacheTable.kCOLUMN_ITEM_TYPE: 'BREAD_newest',
                        },
                      );
                      refreshDataSourceWithScrollToBottom(BoxCacheHandler.commonTable.tableName);
                      BoxerLogger.d(TAG, '--------->>>>> inserted Bread Model [newest] id: $insertedId');
                    }),
                    WidgetUtil.actionSheetItem(Icons.one_k, 'Insert Bread Model [newest customer uuid]',
                        (Map action) async {
                      int insertedId = await BoxCacheHandler.commonTable.mInsertModel<Bread>(
                        BreadGenerator.oneModel,
                        translator: (e, s) => {
                          BoxCacheTable.kCOLUMN_ITEM_TYPE: 'BREAD_newest',
                          BoxCacheTable.kCOLUMN_ITEM_ID: 'XXX${e.uuid}',
                        },
                      );
                      refreshDataSourceWithScrollToBottom(BoxCacheHandler.commonTable.tableName);
                      BoxerLogger.d(TAG, '--------->>>>> inserted Bread Model [newest] id: $insertedId');
                    }),
                    WidgetUtil.actionSheetItem(Icons.one_k, 'Insert Bread Map [newest]', (Map action) async {
                      int insertedId = await BoxCacheHandler.commonTable.mInsert<Map>(
                        BreadGenerator.oneMap(),
                        translator: (e, s) => {
                          BoxCacheTable.kCOLUMN_ITEM_TYPE: 'BREAD_headline',
                        },
                      );
                      refreshDataSourceWithScrollToBottom(BoxCacheHandler.commonTable.tableName);
                      BoxerLogger.d(TAG, '--------->>>>> inserted Bread Map [newest] id: $insertedId');
                    }),
                    WidgetUtil.actionSheetItem(Icons.one_k, 'Insert Bread Map [newest with uuid]', (Map action) async {
                      int insertedId = await BoxCacheHandler.commonTable.mInsert<Map>(
                        BreadGenerator.oneMap(),
                        translator: (e, s) => {
                          BoxCacheTable.kCOLUMN_ITEM_TYPE: 'BREAD_newest',
                          BoxCacheTable.kCOLUMN_ITEM_ID: e['uuid'],
                        },
                      );
                      refreshDataSourceWithScrollToBottom(BoxCacheHandler.commonTable.tableName);
                      BoxerLogger.d(TAG, '--------->>>>> inserted Bread Map [newest] id: $insertedId');
                    }),
                    WidgetUtil.actionSheetItem(Icons.one_k, 'Insert Different UserId & RoleId', (Map action) async {
                      int insertedId = await BoxCacheHandler.commonTable.mInsertModel<Bread>(
                        BreadGenerator.oneModel,
                        translator: (e, s) => {
                          BoxCacheTable.kCOLUMN_ITEM_TYPE: 'XXXXXX',
                          BoxCacheTable.kCOLUMN_USER_ID: 800,
                          BoxCacheTable.kCOLUMN_ROLE_ID: 800900,
                        },
                      );
                      refreshDataSourceWithScrollToBottom(BoxCacheHandler.commonTable.tableName);
                      BoxerLogger.d(TAG, '--------->>>>> inserted Bread Model for Different User: $insertedId');
                    }),
                  ];
                  WidgetUtil.showActionSheet(sheet: sheet);
                },
              ),

              /**
               * Query
               */
              CupertinoButton(
                child: const Text('Query', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () async {
                  List<Map> sheet = [
                    WidgetUtil.actionSheetItem(Icons.one_k, 'All', (Map action) async {
                      List<String?> results = await BoxCacheHandler.commonTable.mQueryAsStrings();
                      BoxerLogger.d(TAG, '--------->>>>> Query all: ${results.length}, ${json.encode(results)}');
                    }),
                    WidgetUtil.actionSheetItem(Icons.one_k, 'All Bread Map', (Map action) async {
                      BoxerQueryOption op =
                          BoxerQueryOption.like(column: BoxCacheTable.kCOLUMN_ITEM_TYPE, value: 'BREAD_%');

                      List<Map> results = await BoxCacheHandler.commonTable.mQueryAsMap(options: op);
                      BoxerLogger.d(
                          TAG, '--------->>>>> Query all bread as map: ${results.length}, ${json.encode(results)}');
                    }),
                    WidgetUtil.actionSheetItem(Icons.one_k, 'All Bread Model', (Map action) async {
                      BoxerQueryOption op =
                          BoxerQueryOption.like(column: BoxCacheTable.kCOLUMN_ITEM_TYPE, value: 'BREAD_%');

                      List<Bread> results = await BoxCacheHandler.commonTable.mQueryAsModels<Bread>(options: op);
                      BoxerLogger.d(TAG, '--------->>>>> Query all bread as model: ${results.length}, $results');
                    }),
                    WidgetUtil.actionSheetItem(Icons.one_k, 'All Bread Model [with fromJson]', (Map action) async {
                      BoxerQueryOption op =
                          BoxerQueryOption.like(column: BoxCacheTable.kCOLUMN_ITEM_TYPE, value: 'BREAD_%');

                      List<Bread> results = await BoxCacheHandler.commonTable.mQueryAsModels<Bread>(
                        options: op,
                        fromJson: (e) => Bread.fromJson(e),
                      );
                      BoxerLogger.d(TAG, '--------->>>>> Query all bread as model: ${results.length}, $results');
                    }),
                  ];
                  WidgetUtil.showActionSheet(sheet: sheet);
                },
              ),

              /**
               * Update
               */
              CupertinoButton(
                child: const Text('Update', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () async {
                  WidgetUtil.showActionSheet(sheet: [
                    WidgetUtil.actionSheetItem(Icons.one_k, 'Update first Bread Model', (Map action) async {
                      BoxerQueryOption op =
                          BoxerQueryOption.like(column: BoxCacheTable.kCOLUMN_ITEM_TYPE, value: 'BREAD_%');
                      List<Bread> results = await BoxCacheHandler.commonTable.mQueryAsModels<Bread>(options: op);
                      Bread? bread = results.firstSafe;
                      bread?.breadContent =
                          '${DatesUtils.format(DateTime.now())}: 🎒🎒🎒❗🎒❗🎒👠❗👠👠❗❗👠❗👠❗👠👠❗ 👠🎒👠❗️';
                      int updateCount = await BoxCacheHandler.commonTable.mUpdateModel<Bread>(bread);
                      ToastHelper.show('Update first Bread content ${updateCount == 1 ? "successfully" : "failed"}');

                      refreshDataSourceWithScrollToBottom(BoxCacheHandler.commonTable.tableName);
                      BoxerLogger.d(TAG, '--------->>>>> model updated count: $updateCount');
                    }),
                    WidgetUtil.actionSheetItem(Icons.one_k, 'Update first Bread using ID', (Map action) async {
                      BoxerQueryOption op =
                          BoxerQueryOption.like(column: BoxCacheTable.kCOLUMN_ITEM_TYPE, value: 'BREAD_%');
                      List<Bread> results = await BoxCacheHandler.commonTable.mQueryAsModels<Bread>(options: op);
                      Bread? bread = results.firstSafe;
                      Map? map = bread?.toJson();
                      map?['breadContent'] = '${DatesUtils.format(DateTime.now())}: 🐶🐶🐶🐶🐶🐶🐶🐶🐶🐶🐶🐶🐶🐶🐶️';
                      int updateCount = await BoxCacheHandler.commonTable.mUpdate(
                        map,
                        options: BoxerQueryOption.eq(columns: [BoxCacheTable.kCOLUMN_ITEM_ID], values: [bread?.uuid]),
                      );
                      ToastHelper.show('Update first Bread content ${updateCount == 1 ? "successfully" : "failed"}');

                      refreshDataSourceWithScrollToBottom(BoxCacheHandler.commonTable.tableName);
                      BoxerLogger.d(TAG, '--------->>>>> model updated count: $updateCount');
                    }),
                    WidgetUtil.actionSheetItem(Icons.one_k, 'Update all Bread Models', (Map action) async {
                      BoxerQueryOption op =
                          BoxerQueryOption.like(column: BoxCacheTable.kCOLUMN_ITEM_TYPE, value: 'BREAD_%');
                      List<Bread> results = await BoxCacheHandler.commonTable.mQueryAsModels<Bread>(options: op);
                      results.forEach((e) {
                        e.breadContent =
                            '${DatesUtils.format(DateTime.now())}: 👠👠👠👠👠👠👠👠👠👠👠👠👠👠👠👠👠👠👠👠👠👠👠👠👠👠👠️';
                      });
                      int updateCount = await BoxCacheHandler.commonTable.mUpdateModels<Bread>(results);
                      ToastHelper.show(
                          'Update all Breads content ${updateCount == results.length ? "successfully" : "failed"}');

                      refreshDataSourceWithScrollToBottom(BoxCacheHandler.commonTable.tableName);
                      BoxerLogger.d(TAG, '--------->>>>> updated count: $updateCount');
                    }),
                    WidgetUtil.actionSheetItem(Icons.one_k, 'Update all Bread Maps', (Map action) async {
                      BoxerQueryOption op =
                          BoxerQueryOption.like(column: BoxCacheTable.kCOLUMN_ITEM_TYPE, value: 'BREAD_%');
                      List<Map> results = await BoxCacheHandler.commonTable.mQueryAsMap(options: op);
                      results.forEach((e) {
                        e['breadContent'] =
                            '${DatesUtils.format(DateTime.now())}: 👑 👑👑👑👑👑👑👑👑👑🕶️🕶️🕶️🕶️🕶️🕶️🕶️🕶️🕶️🕶️🕶️🌂🌂🌂🌂️';
                      });
                      int updateCount = await BoxCacheHandler.commonTable.mUpdates<Map>(results);
                      ToastHelper.show(
                          'Update all Maps content ${updateCount == results.length ? "successfully" : "failed"}');

                      refreshDataSourceWithScrollToBottom(BoxCacheHandler.commonTable.tableName);
                      BoxerLogger.d(TAG, '--------->>>>> updated count: $updateCount');
                    }),
                    WidgetUtil.actionSheetItem(Icons.one_k, 'Update half-count Breads to another UID',
                        (Map action) async {
                      BoxerQueryOption op =
                          BoxerQueryOption.like(column: BoxCacheTable.kCOLUMN_ITEM_TYPE, value: 'BREAD_%');
                      List<Bread> results = await BoxCacheHandler.commonTable.mQueryAsModels<Bread>(options: op);

                      int count = results.length;
                      for (int i = 0; i < count / 2; i++) results.removeAt(0);

                      List<Future<int>> futures = [];
                      results.forEach((bread) async {
                        bread.breadContent = 'USER ID CHANGED!';
                        Future<int> f = BoxCacheHandler.commonTable.mUpdateModel<Bread>(bread, translator: (e, s) {
                          return {
                            BoxCacheTable.kCOLUMN_USER_ID: 100,
                          };
                        });
                        futures.add(f);
                        int v = await f;
                        BoxerLogger.d(TAG, '--------->>>>> element updated count: $v');
                      });

                      List<int> counts = await Future.wait(futures);
                      int updateCount = 0;
                      counts.forEach((e) {
                        updateCount += e;
                      });
                      refreshDataSourceWithScrollToBottom(BoxCacheHandler.commonTable.tableName);
                      BoxerLogger.d(TAG, '--------->>>>> updated count: $updateCount');
                      ToastHelper.show('USER ID CHANGED ${updateCount == count ? "successfully" : "failed"}');
                    }),
                  ]);
                },
              ),

              /**
               * Reset
               */
              CupertinoButton(
                child: const Text('Clear & update 6 times at the same time', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () async {
                  List<Map> sheet = [
                    WidgetUtil.actionSheetItem(Icons.one_k, 'Without Anything', (Map map) {
                      doReset5Times5Items(
                          null); // this will insert 30 items, but we just want to clear all and insert 5 items
                    }),
                    WidgetUtil.actionSheetItem(Icons.one_k, 'With LOCK', (Map map) {
                      doReset5Times5Items(BatchSyncType.LOCK);
                    }),
                    WidgetUtil.actionSheetItem(Icons.one_k, 'With BATCH', (Map map) {
                      doReset5Times5Items(BatchSyncType.BATCH);
                    }),
                    WidgetUtil.actionSheetItem(Icons.one_k, 'With TRANSACTION', (Map map) {
                      doReset5Times5Items(BatchSyncType.TRANSACTION);
                    }),
                  ];
                  WidgetUtil.showActionSheet(sheet: sheet);
                },
              ),
            ],
          ),
          allTableWidgets,
        ],
      ),
    );
  }

  void doReset5Times5Items(BatchSyncType? syncBatchLockTransactionType) {
    int totalCost = 0;
    String lastType = '';

    Future<void> doClearUpdate() async {
      /// Do insert 6 items per-time
      List<Map> sixItems = [
        BreadGenerator.oneMap(),
        BreadGenerator.oneMap(),
        BreadGenerator.oneMap(),
        BreadGenerator.oneMap(),
        BreadGenerator.oneMap(),
        BreadGenerator.oneMap(),
      ];
      String itemType = StringsUtils.random(6);
      int beginTime = DateTime.now().millisecondsSinceEpoch;
      List<Object?>? insertedIds = await BoxCacheHandler.commonTable.resetWithItems<Map>(
        sixItems,
        translator: (e, s) {
          // way 1. the same as way 2
          Map<String, Object?> map = BoxCacheHandler.commonTable.writeTranslator!.call(e, s); // s == map -> true
          map[BoxCacheTable.kCOLUMN_ITEM_TYPE] = 'CLEAR_$itemType';
          map[BoxCacheTable.kCOLUMN_ITEM_ID] = e['uuid'];
          return map;
          // way 2. the same as way 1, cause s will add the following map
          // return {BoxCacheTable.kCOLUMN_ITEM_TYPE: 'CLEAR_$itemType', BoxCacheTable.kCOLUMN_ITEM_ID: e['uuid']};
        },
        syncType: syncBatchLockTransactionType,
      );
      int overTime = DateTime.now().millisecondsSinceEpoch;
      int cost = overTime - beginTime;
      totalCost += cost;
      lastType = itemType;
      BoxerLogger.d(
          TAG, '>>>>> 【$itemType】 cost: ${cost}ms, $syncBatchLockTransactionType, insertion ids: $insertedIds');
      refreshDataSourceWithScrollToBottom(BoxCacheHandler.commonTable.tableName);
    }

    /// Do 5 times async jobs
    List<Future> futures = [];
    for (int i = 0; i < 5; i++) {
      Future f = doClearUpdate();
      futures.add(f);
    }

    /// Print out total cost
    Future.wait(futures).then((value) {
      BoxerLogger.d(TAG, '###### $syncBatchLockTransactionType total cost: ${totalCost}ms, newest type is: $lastType');
    });
  }

  void refreshDataSourceWithScrollToBottom([String? tableName]) {
    /// refresh data & ui
    refresh();

    if (tableName != null) {
      /// scroll to bottom
      scrollTableToBottom(tableName);
    }
  }

  void scrollTableToBottom(String tableName) {
    ScrollController? scrollController = tableListScrollControllerMap[tableName];
    scrollController?.animateTo(
      scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.ease,
    );
  }
}
