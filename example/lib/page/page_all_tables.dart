import 'dart:convert';

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
    await BoxDatabaseManager.boxer.iterateAllTables((tableName, columns) async {
      Map<String, dynamic>? map = {};

      /// Row count for table
      int? rowsCount = await BoxDatabaseManager.boxer.selectCount(tableName);
      List<Map<String, Object?>> rowsResults = await BoxDatabaseManager.boxer.database.query(tableName);

      /// Update to datasource
      map[TableView.keyTblName] = tableName;
      map[TableView.keyTblColumns] = columns;
      map[TableView.keyTblRowCount] = rowsCount;
      map[TableView.keyTblRowResults] = rowsResults;

      datasource.add(map);
      return false;
    });
  }

  Map<String, ScrollController> tableListScrollControllerMap = {};

  Future<void> refreshWholeTablesUIOnly() async {
    List<Widget> children = [];
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
               * Refresh
               */
              CupertinoButton(
                child: Text('Refresh', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () async {
                  refreshDataSourceWithScrollToBottom();
                },
              ),

              /**
               * Clear
               */
              CupertinoButton(
                child: Text('Clear', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () async {
                  List<Map> sheet = [
                    WidgetUtil.actionSheetItem(Icons.one_k, 'Clear force', (Map action) async {
                      await BoxCacheHandler.commonTable.executor.delete(BoxCacheHandler.commonTable.tableName);
                      refreshDataSourceWithScrollToBottom(BoxCacheHandler.commonTable.tableName);
                    }),
                    WidgetUtil.actionSheetItem(Icons.one_k, 'Clear self', (Map action) async {
                      await BoxCacheHandler.commonTable.clear(); // care about the userId & roleId
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
                child: Text('Insert', style: TextStyle(fontWeight: FontWeight.w300)),
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
                        translator: (e) => {
                          BoxCacheTable.kCOLUMN_ITEM_TYPE: 'BREAD_headline',
                        },
                      );
                      refreshDataSourceWithScrollToBottom(BoxCacheHandler.commonTable.tableName);
                      BoxerLogger.d(TAG, '--------->>>>> inserted Bread Model [headline] id: $insertedId');
                    }),
                    WidgetUtil.actionSheetItem(Icons.one_k, 'Insert Bread Model [newest]', (Map action) async {
                      int insertedId = await BoxCacheHandler.commonTable.mInsertModel<Bread>(
                        BreadGenerator.oneModel,
                        translator: (e) => {
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
                        translator: (e) => {
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
                        translator: (e) => {
                          BoxCacheTable.kCOLUMN_ITEM_TYPE: 'BREAD_headline',
                        },
                      );
                      refreshDataSourceWithScrollToBottom(BoxCacheHandler.commonTable.tableName);
                      BoxerLogger.d(TAG, '--------->>>>> inserted Bread Map [newest] id: $insertedId');
                    }),
                    WidgetUtil.actionSheetItem(Icons.one_k, 'Insert Bread Map [newest with uuid]', (Map action) async {
                      int insertedId = await BoxCacheHandler.commonTable.mInsert<Map>(
                        BreadGenerator.oneMap(),
                        translator: (e) => {
                          BoxCacheTable.kCOLUMN_ITEM_TYPE: 'BREAD_newest',
                          BoxCacheTable.kCOLUMN_ITEM_ID: e['uuid'],
                        },
                      );
                      refreshDataSourceWithScrollToBottom(BoxCacheHandler.commonTable.tableName);
                      BoxerLogger.d(TAG, '--------->>>>> inserted Bread Map [newest] id: $insertedId');
                    }),
                  ];
                  WidgetUtil.showActionSheet(sheet: sheet);
                },
              ),

              /**
               * Query
               */
              CupertinoButton(
                child: Text('Query', style: TextStyle(fontWeight: FontWeight.w300)),
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
                child: Text('Update', style: TextStyle(fontWeight: FontWeight.w300)),
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
                        Future<int> f = BoxCacheHandler.commonTable.mUpdateModel<Bread>(bread, translator: (e) {
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
                child: Text('Clear & update 6 times at the same time', style: TextStyle(fontWeight: FontWeight.w300)),
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
      /// Do insert 5 items per-time
      List<Map> fiveItems = [
        BreadGenerator.oneMap(),
        BreadGenerator.oneMap(),
        BreadGenerator.oneMap(),
        BreadGenerator.oneMap(),
        BreadGenerator.oneMap(),
      ];
      String itemType = StringsUtils.random(6);
      int beginTime = DateTime.now().millisecondsSinceEpoch;
      List<Object?>? insertedIds = await BoxCacheHandler.commonTable.resetWithItems<Map>(
        fiveItems,
        translator: (e) {
          Map<String, Object?> map = BoxCacheHandler.commonTable.writeTranslator!.call(e);
          map[BoxCacheTable.kCOLUMN_ITEM_TYPE] = 'CLEAR_$itemType';
          map[BoxCacheTable.kCOLUMN_ITEM_ID] = e['uuid'];
          return map;
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
      duration: Duration(milliseconds: 200),
      curve: Curves.ease,
    );
  }
}
