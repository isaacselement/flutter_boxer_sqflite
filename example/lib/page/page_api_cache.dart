import 'package:example/database/box_database_manager.dart';
import 'package:example/database/biz_table_handler.dart';
import 'package:example/database/box_table_manager.dart';
import 'package:example/model/bread_api.dart';
import 'package:example/widget/table_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dialog_shower/flutter_dialog_shower.dart';
import 'package:synchronized_call/synchronized_call.dart';

class PageApiCache extends StatefulWidget {
  PageApiCache({Key? key}) : super(key: key);

  @override
  PageApiCacheState createState() => PageApiCacheState();
}

class PageApiCacheState extends State<PageApiCache> with WidgetsBindingObserver {
  Widget allTableWidgets = Column();

  Map<String, ScrollController> listScrollControllers = {};
  Map<String, Btv<int?>> selectedIndexes = {};

  @override
  void initState() {
    super.initState();
    Boxes.getWidgetsBinding().addObserver(this);
    refreshDataSource();
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

    Map<String, dynamic>? map = {};

    /// show sqlite_master
    String tableName = BoxTableManager.kNAME_ARTICLE_LIST;

    Future<List<dynamic>> cacheResultsFuture = BizTableArticleList.getArticleList('newest');
    Future<List<dynamic>> cacheFuture = Future.delayed(Duration(milliseconds: 1000), () => cacheResultsFuture);
    // Future<List<dynamic>> cacheFuture = Future.delayed(Duration(milliseconds: 5000), () => cacheResultsFuture);
    Future<List<dynamic>> apiListFuture = BreadApi.getList();
    BoxCacheHandler.getData<List<dynamic>>(
      cacheFuture: cacheFuture,
      requestFuture: apiListFuture,
      updateCache: (value) {
        BizTableArticleList.updateArticleList(value, 'newest');
      },
      updateView: (value, isFromCache) {
        datasource.clear();

        List<dynamic> rowsResults = value;
        map[kTbName] = tableName;
        map[kTbColumns] = [
          'breadId',
          'uuid',
          'breadType',
          'breadContent',
          'breadUpdateTime',
          'breadCreateTime',
          'breadTagList',
        ];
        map[kTbRowCount] = rowsResults.length;
        map[kTbRowResults] = rowsResults;

        datasource.add(map);
        listScrollControllers[tableName] ??= ScrollController();

        refreshTablesUIOnly();
      },
    );
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
        height: 600,
        isShowSeq: true,
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
          allTableWidgets,
        ],
      ),
    );
  }
}
