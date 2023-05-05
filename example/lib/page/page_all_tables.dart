import 'dart:convert';

import 'package:example/common/util/date_util.dart';
import 'package:example/database/box_database_manager.dart';
import 'package:example/database/biz_table_cache.dart';
import 'package:example/database/box_table_manager.dart';
import 'package:example/model/bread.dart';
import 'package:example/widget/table_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';
import 'package:flutter_dialog_shower/flutter_dialog_shower.dart';
import 'package:synchronized_call/synchronized_call.dart';

class PageAllTables extends StatefulWidget {
  PageAllTables({Key? key}) : super(key: key);

  @override
  PageAllTablesState createState() => PageAllTablesState();
}

class PageAllTablesState extends State<PageAllTables> with WidgetsBindingObserver {
  Widget allTableWidgets = Column();

  Map<String, ScrollController> listScrollControllers = {};
  Map<String, Btv<int?>> selectedIndexes = {};

  @override
  void initState() {
    super.initState();
    Boxes.getWidgetsBinding().addObserver(this);

    BizTableCache.currentUid = 110;
    BizTableCache.currentRoleId = 10086;

    refresh();
  }

  @override
  void dispose() {
    Boxes.getWidgetsBinding().removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    refreshTablesUIOnly();
  }

  Future<void> refresh() async {
    await refreshDataSource();
    refreshTablesUIOnly();
  }

  static const String kTbName = 'tbl_name';
  static const String kTbColumns = 'tbl_columns';
  static const String kTbRowCount = 'tbl_row_count';
  static const String kTbRowResults = 'tbl_row_results';
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
      map[kTbName] = tableName;
      map[kTbColumns] = columns;
      map[kTbRowCount] = rowsCount;
      map[kTbRowResults] = rowsResults;

      datasource.add(map);
      listScrollControllers[tableName] ??= ScrollController();
    });
  }

  Future<void> refreshTablesUIOnly() async {
    List<Widget> oneTableColumnChildren = [];
    for (int i = 0; i < datasource.length; i++) {
      Map<String, dynamic> map = datasource[i];
      String tableName = map[kTbName];

      Widget oneTableWidget = TableView(
        tableName: tableName,
        columnNames: List<String>.from(map[kTbColumns]),
        rowsCount: map[kTbRowCount],
        rowsResults: List<Map<String, Object?>>.from(map[kTbRowResults]),
        scrollController: listScrollControllers[tableName],
      );
      oneTableColumnChildren.add(oneTableWidget);
    }

    oneTableColumnChildren.add(SizedBox(height: 38));
    allTableWidgets = Column(children: oneTableColumnChildren);
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
                  List<Map> results = await BoxTableManager.articleListTable.mQueryAsMap();
                  List<Bread> breads = await BoxTableManager.articleListTable.mQueryAsModels<Bread>(fromJson: (e) => Bread.fromJson(e));
                  BxLoG.d('--------->>>>> query all as map: ${json.encode(results)}');
                  BxLoG.d('--------->>>>> query all as breads: $breads');
                },
              ),
              CupertinoButton(
                child: Text('Clear & Reset auto id', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () async {
                  await BoxTableManager.articleListTable.clear();
                  await BoxTableManager.articleListTable.resetAutoId();
                  refreshDataSourceWithScrollToBottom();
                },
              ),
              CupertinoButton(
                child: Text('Insert one', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () async {
                  int rowId = await BoxTableManager.articleListTable.mInsert<Map>(BreadFake.oneMap(), translator: (e) {
                    Map<String, Object?> map = BoxTableManager.articleListTable.insertionTranslator!.call(e);
                    map[BizTableCache.kCOLUMN_TYPE] = 'newest';
                    // map[BizTableCache.kCOLUMN_ITEM_ID] = e['uuid'];
                    return map;
                  });
                  BxLoG.d('--------->>>>> inserted id Map: $rowId');

                  int insertRowId0 = await BoxTableManager.articleListTable.mInsertModel<Bread>(BreadFake.oneModel);
                  int insertRowId1 = await BoxTableManager.articleListTable.mInsertModel<Bread>(
                    BreadFake.oneModel,
                    translator: (e) => {BizTableCache.kCOLUMN_TYPE: 'headline'},
                  );
                  BxLoG.d('--------->>>>> inserted id Bread Model: $insertRowId0, $insertRowId1');

                  refreshDataSourceWithScrollToBottom(BoxTableManager.kNAME_ARTICLE_LIST);
                },
              ),
              CupertinoButton(
                child: Text('Update one', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () async {
                  // String name = 'kNAME_ARTICLE_LIST';
                  // BizTableCache tbl = BizTableCache(tableName: name)..database = BizTableManager.articleListTable.database;
                  // bool isExisted = await tbl.isTableExisted();
                  // BxLoG.d('======= $isExisted');
                  // List<Map<String, Object?>> result = await tbl.database.rawQuery('select * from $name');
                  // BxLoG.d('======= $result');

                  Bread? bread = (await BoxTableManager.articleListTable.mQueryAsModels(fromJson: (e) => Bread.fromJson(e))).firstSafe;
                  bread?.breadContent = '${DateUtil.format(DateTime.now())}: Yes, i agree~~~~~~~ 👠⌘🎒👠❗️';
                  // int updateCount = await BizTableManager.articleListTable.mUpdateModel(bread, options: BoxerQueryOption.eq(columns: [BizTableCache.kCOLUMN_ITEM_ID], values: [bread?.uuid]));
                  int updateCount = await BoxTableManager.articleListTable.mUpdateModel(bread);
                  BxLoG.d('--------->>>>> model updated count: $updateCount');
                  refreshDataSourceWithScrollToBottom(BoxTableManager.kNAME_ARTICLE_LIST);
                },
              ),
              CupertinoButton(
                child: Text('Clear & update with Sync lock', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () async {
                  doReset(BatchSyncType.LOCK);
                },
              ),
              CupertinoButton(
                child: Text('Clear & update with Sync batch', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () async {
                  doReset(BatchSyncType.BATCH);
                },
              ),
              CupertinoButton(
                child: Text('Clear & update with Sync transaction', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () async {
                  doReset(BatchSyncType.TRANSACTION);
                },
              ),
              CupertinoButton(
                child: Text('Clear & update without Sync', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () async {
                  doReset(null);
                },
              ),
            ],
          ),
          allTableWidgets,
        ],
      ),
    );
  }

  void doReset(BatchSyncType? batchSyncType) {
    Future<void> doClearUpdate() async {
      List<Map> items = [BreadFake.oneMap(), BreadFake.oneMap(), BreadFake.oneMap(), BreadFake.oneMap()];
      List<Object?>? insertionIds = await BoxTableManager.articleListTable.resetWithItems<Map>(items, translator: (e) {
        Map<String, Object?> map = BoxTableManager.articleListTable.insertionTranslator!.call(e);
        map[BizTableCache.kCOLUMN_TYPE] = 'force_read';
        map[BizTableCache.kCOLUMN_ITEM_ID] = e['uuid'];
        return map;
      }, syncType: batchSyncType);
      BxLoG.d('--->>>>> $batchSyncType insertion ids: $insertionIds');
      refreshDataSourceWithScrollToBottom(BoxTableManager.kNAME_ARTICLE_LIST);
    }

    for (int i = 0; i < 5; i++) doClearUpdate();
  }

  void refreshDataSourceWithScrollToBottom([String? tableName]) {
    /// refresh data & ui
    refresh();

    if (tableName == null) return;

    /// scroll to bottom
    scrollTableToBottom(tableName);
  }

  void scrollTableToBottom(String tableName) {
    ScrollController? scrollController = listScrollControllers[tableName];
    scrollController?.animateTo(
      scrollController.position.maxScrollExtent,
      duration: Duration(milliseconds: 200),
      curve: Curves.ease,
    );
  }
}
