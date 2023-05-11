import 'dart:convert';

import 'package:example/common/util/dates_utils.dart';
import 'package:example/common/util/widget_util.dart';
import 'package:example/database/box_cache_table.dart';
import 'package:example/database/box_database_manager.dart';
import 'package:example/database/box_table_manager.dart';
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
              CupertinoButton(
                child: Text('Refresh all', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () async {
                  refreshDataSourceWithScrollToBottom();
                },
              ),
              CupertinoButton(
                child: Text('Get all', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () async {
                  List<Map> results = await BoxTableManager.bizCacheTable.mQueryAsMap();
                  List<Bread> breads =
                      await BoxTableManager.bizCacheTable.mQueryAsModels<Bread>(fromJson: (e) => Bread.fromJson(e));
                  BoxerLogger.d(TAG, '--------->>>>> query all as map: ${json.encode(results)}');
                  BoxerLogger.d(TAG, '--------->>>>> query all as breads: $breads');
                },
              ),
              CupertinoButton(
                child: Text('Clear & Reset auto id', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () async {
                  await BoxTableManager.bizCacheTable.clear();
                  await BoxTableManager.bizCacheTable.resetAutoId();
                  refreshDataSourceWithScrollToBottom();
                },
              ),
              CupertinoButton(
                child: Text('Insert one', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () async {
                  int insertRowId0 = await BoxTableManager.bizCacheTable.mInsertModel<Bread>(BreadGenerator.oneModel);
                  int insertRowId1 = await BoxTableManager.bizCacheTable.mInsertModel<Bread>(
                    BreadGenerator.oneModel,
                    translator: (e) => {
                      BoxCacheTable.kCOLUMN_ITEM_TYPE: 'headline',
                    },
                  );
                  BoxerLogger.d(TAG, '--------->>>>> inserted id Bread Model: $insertRowId0, $insertRowId1');

                  int insertRowId2 = await BoxTableManager.bizCacheTable.mInsert<Map>(
                    BreadGenerator.oneMap(),
                    translator: (e) {
                      Map<String, Object?> map = BoxTableManager.bizCacheTable.insertionTranslator!.call(e);
                      map[BoxCacheTable.kCOLUMN_ITEM_TYPE] = 'newest';
                      // map[BoxCacheTable.kCOLUMN_ITEM_ID] = e['uuid'];
                      return map;
                    },
                  );
                  BoxerLogger.d(TAG, '--------->>>>> inserted id Map: $insertRowId2');

                  refreshDataSourceWithScrollToBottom(BoxTableManager.kNAME_BIZ_COMMON);
                },
              ),
              CupertinoButton(
                child: Text('Update one', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () async {
                  List<Bread> results =
                      await BoxTableManager.bizCacheTable.mQueryAsModels(fromJson: (e) => Bread.fromJson(e));
                  Bread? bread = results.firstSafe;
                  bread?.breadContent = '${DatesUtils.format(DateTime.now())}: Yes, i agree~~~~~~~ 👠⌘🎒👠❗️';
                  // int updateCount = await BoxTableManager.bizCacheTable.mUpdateModel(
                  //   bread,
                  //   options: BoxerQueryOption.eq(columns: [BoxCacheTable.kCOLUMN_ITEM_ID], values: [bread?.uuid]),
                  // );
                  int updateCount = await BoxTableManager.bizCacheTable.mUpdateModel(bread);
                  BoxerLogger.d(TAG, '--------->>>>> model updated count: $updateCount');
                  refreshDataSourceWithScrollToBottom(BoxTableManager.kNAME_BIZ_COMMON);
                },
              ),
              CupertinoButton(
                child: Text('Clear & update', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () async {
                  Map<String, dynamic> action(IconData i, String s, Function(Map m) f) =>
                      {'icon': i, 'text': s, 'event': f};
                  List<Map> sheet = [
                    action(Icons.one_k, 'Without Anything', (Map map) {
                      doReset(null); // this will insert 30 items, but we just want to clear all and insert 5 items
                    }),
                    action(Icons.one_k, 'With LOCK', (Map map) {
                      doReset(BatchSyncType.LOCK);
                    }),
                    action(Icons.one_k, 'With BATCH', (Map map) {
                      doReset(BatchSyncType.BATCH);
                    }),
                    action(Icons.one_k, 'With TRANSACTION', (Map map) {
                      doReset(BatchSyncType.TRANSACTION);
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

  void doReset(BatchSyncType? syncBatchLockTransactionType) {
    int totalCost = 0;
    String lastType = '';

    Future<void> doClearUpdate() async {
      List<Map> fiveItems = [
        BreadGenerator.oneMap(),
        BreadGenerator.oneMap(),
        BreadGenerator.oneMap(),
        BreadGenerator.oneMap(),
        BreadGenerator.oneMap(),
      ];
      String itemType = StringsUtils.random(6);
      int beginTime = DateTime.now().millisecondsSinceEpoch;
      List<Object?>? insertedIds = await BoxTableManager.bizCacheTable.resetWithItems<Map>(
        fiveItems,
        translator: (e) {
          Map<String, Object?> map = BoxTableManager.bizCacheTable.insertionTranslator!.call(e);
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
      refreshDataSourceWithScrollToBottom(BoxTableManager.kNAME_BIZ_COMMON);
    }

    /// do 6 times async jobs
    List<Future> futures = [];
    for (int i = 0; i < 6; i++) {
      Future f = doClearUpdate();
      futures.add(f);
    }

    /// print out total cost
    Future.wait(futures).then((value) {
      BoxerLogger.d(TAG, '###### $syncBatchLockTransactionType total cost: ${totalCost}ms, newest type is: $lastType');
    });
  }

  void refreshDataSourceWithScrollToBottom([String? tableName]) {
    /// refresh data & ui
    refresh();

    if (tableName == null) return;

    /// scroll to bottom
    scrollTableToBottom(tableName);
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
