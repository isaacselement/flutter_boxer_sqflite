import 'dart:async';
import 'dart:math';

import 'package:example/common/util/toast_helper.dart';
import 'package:example/common/util/widget_util.dart';
import 'package:example/database/box_cache_handler.dart';
import 'package:example/database/box_cache_table.dart';
import 'package:example/database/box_cache_tasks.dart';
import 'package:example/widget/table_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';
import 'package:flutter_dialog_shower/flutter_dialog_shower.dart';
import 'package:synchronized_call/synchronized_call.dart';
import 'package:http/http.dart' as http;

class PageTasksTable extends StatefulWidget {
  PageTasksTable({Key? key}) : super(key: key);

  @override
  PageTasksTableState createState() => PageTasksTableState();
}

class PageTasksTableState extends State<PageTasksTable> with WidgetsBindingObserver {
  static const String TAG = 'PageTasksTable';

  Btv<bool> isGlobalTaskBtv = Btv<bool>(false);

  @override
  void initState() {
    super.initState();
    Boxes.getWidgetsBinding().addObserver(this);
    refreshTableViewDatasource();

    isGlobalTaskBtv.listen((data) {
      if (data) {
        ToastHelper.show('The better practice is keep a new [BoxCacheTasks] instance for Global.');
        BoxCacheTable table = mTable.cloneInstance as BoxCacheTable;
        table.isUserIdConcerned = false;
        table.isRoleIdConcerned = false;
        BoxCacheTasks.instance.table = table;
      } else {
        BoxCacheTasks.instance.table = mTable;
      }
    });
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

  BoxCacheTable get mTable => BoxCacheHandler.cacheTableTasks;

  @override
  Widget build(BuildContext context) {
    initBoxTasksHandler();

    Map<String, dynamic> action(IconData i, String s, Function(Map m) f) {
      return WidgetUtil.actionSheetItem(i, s, (e) async {
        f(e);
        await Future.delayed(Duration(milliseconds: 200));
        refreshTableViewDatasource();
      });
    }

    VoidCallback wrapPress(VoidCallback fn) {
      return () async {
        fn();
        await Future.delayed(Duration(milliseconds: 250));
        refreshTableViewDatasource();
      };
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Wrap(
            children: [
              /**
               * Switch Tasks is not care about User
               */
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: WidgetUtil.oneSwitcher(text: 'Global?', value: isGlobalTaskBtv),
              ),

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
               * About Tasks
               */
              CupertinoButton(
                child: Text('Add a http task', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: wrapPress(() async {
                  String id = DateTime.now().millisecondsSinceEpoch.toString();
                  bool isPost = Random().nextBool();
                  BoxCacheTasks.instance.addTask(BoxTask(
                    type: 'TASK_TYPE_REQUEST',
                    id: '$id',
                    data: {
                      'id': id,
                      'method': isPost ? 'POST' : 'GET',
                      'url': isPost ? 'https://www.baidu.com' : 'http://myip.ipip.net/',
                    },
                  ));
                }),
              ),
              CupertinoButton(
                child: Text('Add a same http task', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: wrapPress(() async {
                  BoxTaskFeign? wrap = await BoxCacheTasks.instance.mTable.first<BoxTaskFeign>(
                    type: 'TASK_TYPE_REQUEST',
                  );
                  if (wrap != null) {
                    BoxTask task = wrap.task;
                    task.data['method'] = 'POST';
                    task.data['url'] = 'http://ip-api.com/json/24.48.0.1?fields=61439';
                    BoxCacheTasks.instance.addTask(task);
                  }
                }),
              ),
              CupertinoButton(
                child: Text('Tasks', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () async {
                  List<Map> sheet = [
                    action(Icons.one_k, 'Add a 2s Task', (Map action) async {
                      BoxCacheTasks.instance.addTask(BoxTask(
                        type: 'WAIT_ME',
                        id: '${DateTime.now().millisecondsSinceEpoch}',
                        data: {},
                      ));
                    }),
                    action(Icons.one_k, 'Add a should do check Task', (Map action) async {
                      BoxCacheTasks.instance.addTask(BoxTask(
                        type: 'SHOULD_DO_CHECK',
                        id: '${DateTime.now().millisecondsSinceEpoch}',
                        data: {},
                      ));
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

  static bool isInit = false;

  void initBoxTasksHandler() {
    if (isInit) return;
    isInit = true;

    FutureOr<bool> doTask(BoxTaskFeign task) async {
      bool isSuccess = false;
      try {
        isSuccess = await executeTask(task);
      } catch (e, s) {
        BoxerLogger.e(TAG, 'Do task $task error: $e, $s');
      }

      // toast and refresh view
      BoxerLogger.d(TAG, 'Do a task$task ${isSuccess ? 'success' : 'failed'}');
      ToastHelper.show('Do a task$task ${isSuccess ? 'success' : 'failed'}');
      Future.delayed(Duration(milliseconds: 600), () {
        CallLock.got<InclusiveLock>(TAG).call(() async {
          await refreshTableViewDatasource();
        });
      });
      return isSuccess;
    }

    BoxCacheTasks.instance.table = mTable;
    BoxCacheTasks.instance.doTask = doTask;
    BoxerTableTranslator.setModelTranslator<BoxTaskFeign>(
      (Map e) => BoxTaskFeign.fromJson(e),
      (BoxTaskFeign e) => e.toJson(),
      (BoxTaskFeign e) => {BoxCacheTable.kCOLUMN_ITEM_TYPE: e.type, BoxCacheTable.kCOLUMN_ITEM_ID: e.id},
    );

    int flag = 0;
    BoxCacheTasks.instance.putIfExecutor((current, previous) async {
      if (current.task.type == 'SHOULD_DO_CHECK') {
        bool isDo = flag++ > 2;
        flag = isDo ? 0 : flag;
        BoxerLogger.d(TAG, '--------------->>> Do the should do task $current or not: $isDo');
        return isDo;
      }
      return true;
    });
  }

  Future<bool> executeTask(BoxTaskFeign task) async {
    String type = task.type;
    BoxerLogger.d(TAG, 'Task doing: $task');
    if (type == 'TASK_TYPE_REQUEST') {
      await Future.delayed(Duration(milliseconds: 5 * 1000));

      Map data = task.task.data;
      var method = data['method'];
      var url = Uri.parse(data['url']);
      BoxerLogger.d(TAG, 'Requesting: $method -> $url');

      var response;
      if (method == 'GET') {
        response = await http.get(url);
      } else if (method == 'POST') {
        response = await http.post(url, body: data['body']);
      }

      BoxerLogger.d(TAG, '###### Response status: ${response.statusCode}, body: \n${response.body}');
      return true;
    } else if (type == 'WAIT_ME') {
      await Future.delayed(Duration(milliseconds: 2 * 1000));
      return true;
    } else if (type == 'SHOULD_DO_CHECK') {
      await Future.delayed(Duration(milliseconds: 1 * 1000));
      return true;
    }
    return false;
  }
}
