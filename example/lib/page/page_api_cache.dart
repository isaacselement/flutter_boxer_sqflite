import 'dart:async';

import 'package:example/common/util/toast_helper.dart';
import 'package:example/database/box_cache_handler.dart';
import 'package:example/database/box_database_manager.dart';
import 'package:example/model/bread_api.dart';
import 'package:example/widget/table_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';
import 'package:flutter_dialog_shower/flutter_dialog_shower.dart';

class PageApiCache extends StatefulWidget {
  PageApiCache({Key? key}) : super(key: key);

  @override
  PageApiCacheState createState() => PageApiCacheState();
}

class PageApiCacheState extends State<PageApiCache> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    Boxes.getWidgetsBinding().addObserver(this);

    clearDatasource();

    refreshDataSourceDuration(
      cacheDuration: Duration(milliseconds: 1000),
      requestDuration: Duration(milliseconds: 3000),
    );
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

  @override
  Widget build(BuildContext context) {
    Widget createTableView() {
      List<Widget> children = [];
      for (int i = 0; i < datasource.length; i++) {
        Map<String, dynamic> map = datasource[i];
        String tableName = map[TableView.keyTblName];

        Widget oneTableWidget = TableView(
          tableName: tableName,
          columnNames: List<String>.from(map[TableView.keyTblColumns]),
          rowsCount: map[TableView.keyTblRowCount],
          rowsResults: List<Map<String, Object?>>.from(map[TableView.keyTblRowResults]),
          scrollController: listScrollControllers[tableName],
          height: 600,
          isShowSeq: true,
        );
        children.add(oneTableWidget);
      }
      if (children.isNotEmpty) {
        children.add(SizedBox(height: 38));
      }
      return Column(children: children);
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Wrap(
            runAlignment: WrapAlignment.center,
            children: [
              CupertinoButton(
                child: Text('Clear Screen', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () {
                  clearDatasource();
                },
              ),
              CupertinoButton(
                child: Text('Cache first then Request', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () async {
                  refreshDataSourceDuration(
                    cacheDuration: Duration(milliseconds: 1000),
                    requestDuration: Duration(milliseconds: 3000),
                  );
                },
              ),
              CupertinoButton(
                child: Text('Request first then Cache', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () async {
                  refreshDataSourceDuration(
                    cacheDuration: Duration(milliseconds: 3000),
                    requestDuration: Duration(milliseconds: 1000),
                  );
                },
              ),
            ],
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Cache Error'),
                  Switch(
                    value: isThrowErrorOnCache,
                    activeColor: Colors.red,
                    onChanged: (bool value) {
                      setState(() {
                        isThrowErrorOnCache = value;
                      });
                    },
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Request Error'),
                  Switch(
                    value: isThrowErrorOnRequest,
                    activeColor: Colors.red,
                    onChanged: (bool value) {
                      setState(() {
                        isThrowErrorOnRequest = value;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          // table view
          createTableView(),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> datasource = [];
  Map<String, ScrollController> listScrollControllers = {};

  bool isThrowErrorOnCache = false;
  bool isThrowErrorOnRequest = false;

  void clearDatasource() {
    String tableName = BoxCacheHandler.commonTable.tableName;
    listScrollControllers[tableName] ??= ScrollController();

    datasource.clear();
    Map<String, dynamic>? map = {};
    List<dynamic> rowsResults = [];
    map[TableView.keyTblName] = tableName;
    map[TableView.keyTblColumns] = BreadGenerator.oneModel.toJson().keys.toList();
    map[TableView.keyTblRowCount] = rowsResults.length;
    map[TableView.keyTblRowResults] = rowsResults;
    datasource.add(map);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> refreshDataSourceDuration({
    Duration? cacheDuration,
    Duration? requestDuration,
  }) async {
    // Future<List<dynamic>>? cacheFuture = null;
    Future<List<dynamic>>? cacheFuture = () async {
      await Future.delayed(cacheDuration ?? const Duration(milliseconds: 5000));
      return await loadFromCache();
    }();

    // Future<List<dynamic>>? requestFuture = null;
    Future<List<dynamic>>? requestFuture = () async {
      await Future.delayed(requestDuration ?? const Duration(milliseconds: 3000));
      return await loadFromRequest();
    }();

    await refreshDataSource(cacheFuture: cacheFuture, requestFuture: requestFuture);
  }

  Future<void> refreshDataSource({
    required Future<List<dynamic>>? cacheFuture,
    required Future<List<dynamic>>? requestFuture,
  }) async {
    await BoxDatabaseManager.init();

    BoxerLoader<List<dynamic>> handler = BoxerLoader(
      howToUpdateCache: (value) {
        updateToCache(value);
      },
      howToUpdateView: (value, bool isFromCache) {
        Map<String, dynamic>? map = datasource.first;
        map[TableView.keyTblRowCount] = value.length;
        map[TableView.keyTblRowResults] = value;
        if (mounted) {
          setState(() {});
        }
      },
      onLoadError: (error, stack, errorType) {
        String msg = "##### Error: $error [$errorType]";
        if (errorType == BoxerLoadType.CACHE) {
          ToastHelper.showRed(msg);
        } else {
          ToastHelper.showGreen(msg);
        }
      },
    );

    handler.getData(loadRequestFuture: requestFuture, loadCacheFuture: cacheFuture).then((value) {
      // null if error
      print('Fallback 【getData】 DONE: $value');
      if (value == null) {
        ToastHelper.showRed('Fallback: Failed!!! value is null!!!');
      } else {
        ToastHelper.showRed('Fallback: Success get value');
      }
    }).onError((e, s) {
      // not possible
      print('Fallback 【getData】 ERROR: $e, $s');
    });
  }

  Future<List<dynamic>> loadFromRequest() async {
    if (isThrowErrorOnRequest) {
      throw Exception('Request error');
    }
    return await BreadApi.getList();
  }

  Future<List<dynamic>> loadFromCache() async {
    if (isThrowErrorOnCache) {
      throw Exception('Cache error');
    }
    return await BoxCommonTableHandler.loadDataList('BREAD');
  }

  Future<void> updateToCache(List<dynamic> value) async {
    await BoxCommonTableHandler.updateDataList(value, 'BREAD');
  }
}
