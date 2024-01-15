import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:example/app.dart';
import 'package:example/common/util/toast_helper.dart';
import 'package:example/common/util/widget_util.dart';
import 'package:example/database/box_cache_handler.dart';
import 'package:example/database/box_cache_table.dart';
import 'package:example/database/box_cache_tasks.dart';
import 'package:example/database/box_tasks_manager.dart';
import 'package:example/widget/table_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';
import 'package:flutter_dialog_shower/flutter_dialog_shower.dart';
import 'package:http/http.dart';
import 'package:http/http.dart' as http;
import 'package:synchronized_call/synchronized_call.dart';

class PageTasksTable extends StatefulWidget {
  PageTasksTable({Key? key}) : super(key: key);

  @override
  PageTasksTableState createState() => PageTasksTableState();
}

class PageTasksTableState extends State<PageTasksTable> with WidgetsBindingObserver {
  static const String TAG = 'PageTasksTable';

  Btv<bool> isGlobalTaskBtv = Btv<bool>(false);
  Btv<bool> isNetworkDisconnected = Btv<bool>(false);

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
        BoxTasksManager.cacheTasks.table = table;
      } else {
        BoxTasksManager.cacheTasks.table = mTable;
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
    if (map.isEmpty) return const SizedBox();
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
    Map<String, dynamic> action(IconData i, String s, Function(Map m) f) {
      return WidgetUtil.actionSheetItem(i, s, (e) async {
        f(e);
        await Future.delayed(const Duration(milliseconds: 200));
        refreshTableViewDatasource();
      });
    }

    VoidCallback wrapPress(VoidCallback fn) {
      return () async {
        fn();
        await Future.delayed(const Duration(milliseconds: 250));
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
                child: WidgetUtil.oneSwitcher(text: 'Global Task?', value: isGlobalTaskBtv),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: WidgetUtil.oneSwitcher(
                  text: 'Network Disconnected?',
                  value: isNetworkDisconnected,
                  onChanged: (oldValue, newValue) {
                    BoxTasksManager.setNetworkStatus(newValue == false);
                  },
                ),
              ),

              /**
               * Refresh
               */
              CupertinoButton(
                child: const Text('Refresh', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () async {
                  refreshTableViewDatasource();
                },
              ),

              /**
               * Actions
               */
              CupertinoButton(
                child: const Text('Actions', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () async {
                  List<Map> sheet = [
                    action(Icons.stop_circle_outlined, 'Stop', (Map action) async {
                      BoxTasksManager.cacheTasks.stop();
                    }),
                    action(Icons.play_circle_outlined, 'Resume', (Map action) async {
                      BoxTasksManager.cacheTasks.resume();
                    }),
                    action(Icons.clear_outlined, 'Clear self', (Map action) async {
                      await mTable.delete(); // care about the userId & roleId
                    }),
                    action(Icons.clear_all_outlined, 'Clear force', (Map action) async {
                      await mTable.executor.delete(mTable.tableName);
                    }),
                    action(Icons.circle, 'Reset auto id', (Map action) async {
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
                onPressed: wrapPress(() async {
                  String taskId = DateTime.now().millisecondsSinceEpoch.toString();
                  bool isPost = Random().nextBool();
                  String path = isPost ? 'https://www.baidu.com' : 'http://myip.ipip.net/';
                  BoxTasksManager.addHttpTask(taskId, path, isHttpPost: isPost, isNeedFuture: true)?.then((value) {
                    BoxerLogger.d(TAG, "FUTURE IS OK ${value.data is Response?}. ERROR: ${value.error}");
                  });
                }),
                child: const Text('Add a http task', style: TextStyle(fontWeight: FontWeight.w300)),
              ),
              CupertinoButton(
                onPressed: wrapPress(() async {
                  BoxTaskFeign? httpTask =
                      await BoxTasksManager.cacheTasks.mTable.last<BoxTaskFeign>(type: BoxTaskType.HTTP_BIGGER);
                  if (httpTask != null) {
                    BoxTask task = httpTask.task;
                    task.data['method'] = 'POST';
                    task.data['path'] = null;
                    task.data['url'] = 'http://ip-api.com/json/24.48.0.1?fields=61439';
                    BoxTasksManager.cacheTasks.addTask(task);
                  }
                }),
                child: const Text('Add a same http task', style: TextStyle(fontWeight: FontWeight.w300)),
              ),
              CupertinoButton(
                child: const Text('Tasks', style: TextStyle(fontWeight: FontWeight.w300)),
                onPressed: () async {
                  List<Map> sheet = [
                    action(Icons.timelapse, 'Add a caller doing Task', (Map action) async {
                      String taskId = DateTime.now().millisecondsSinceEpoch.toString();
                      String path = 'http://myip.ipip.net/';
                      BoxTasksManager.addHttpTask(taskId, path, isHttpPost: false);
                      BoxTasksManager.setHttpTaskDoingByMeNow(taskId);
                      bool isDoingByMeSuccess = false;
                      try {
                        var result = await http.get(Uri.parse(path));
                        await Future.delayed(const Duration(seconds: 3));
                        if (kDebugMode && isNetworkDisconnected.value == true) {
                          throw const SocketException('connection is disconnected');
                        }
                        BoxerLogger.d(TAG, "HTTP GET RESULT: $result");
                        isDoingByMeSuccess = true;
                      } catch (e, s) {
                        isDoingByMeSuccess = false;
                        BoxerLogger.d(TAG, "HTTP GET ERROR: $e, $s");
                      } finally {
                        BoxTasksManager.removeHttpTaskDoingByMeNow(taskId, isDoingByMeSuccess);
                      }
                    }),
                    action(Icons.one_k, 'Add a 2s Task', (Map action) async {
                      BoxTasksManager.cacheTasks.addTask(BoxTask(
                        type: 'WAIT_ME',
                        id: '${DateTime.now().millisecondsSinceEpoch}',
                        data: {},
                      ));
                    }),
                    action(Icons.one_k, 'Add a should do check Task', (Map action) async {
                      BoxTasksManager.cacheTasks.addTask(BoxTask(
                        type: 'SHOULD_DO_CHECK',
                        id: '${DateTime.now().millisecondsSinceEpoch}',
                        data: {},
                      ));
                    }),
                    action(Icons.one_k, 'Add always failed Task', (Map action) async {
                      BoxTasksManager.cacheTasks.addTask(
                        BoxTask(
                          type: 'FAILED_TASK',
                          id: '${DateTime.now().millisecondsSinceEpoch}',
                          data: {},
                        ),
                      );
                    }),
                    action(Icons.one_k, 'Add always failed Task (3)', (Map action) async {
                      BoxTasksManager.cacheTasks.addTask(
                        BoxTask(
                          type: 'FAILED_TASK',
                          id: '${DateTime.now().millisecondsSinceEpoch}',
                          data: {},
                        ),
                        maxCount: 3,
                      );
                    }),
                    action(Icons.one_k, 'Add 10 async/sync task', (Map action) async {
                      List<BoxTask> tasks = [];
                      for (int i = 0; i < 10; i++) {
                        String taskId = (DateTime.now().millisecondsSinceEpoch + i).toString();
                        BoxTask task = BoxTask(
                          type: BoxTaskType.HTTP_SMALL,
                          id: taskId,
                          isAsync: Random().nextBool(),
                          data: {'id': taskId, 'method': 'GET', 'url': 'http://myip.ipip.net/'},
                        );
                        tasks.add(task);
                      }
                      tasks.shuffle();
                      for (BoxTask task in tasks) {
                        BoxTasksManager.cacheTasks.addTask(task);
                      }
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

  static void refreshToastTaskDoneExecuteStatus(BoxTaskFeign task, bool isSuccess) {
    ToastHelper.show('Do a task$task ${isSuccess ? 'success' : 'failed'}');
    Future.delayed(const Duration(milliseconds: 600), () {
      CallLock.got<InclusiveLock>(TAG).call(() async {
        await (ElementsUtils.getStateOfType<PageTasksTableState>(AppState.appContext))?.refreshTableViewDatasource();
      });
    });
  }
}
