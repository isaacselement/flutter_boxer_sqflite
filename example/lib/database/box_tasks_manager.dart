import 'dart:async';
import 'dart:io';

import 'package:example/database/box_cache_tasks.dart';
import 'package:example/database/box_database_manager.dart';
import 'package:example/page/page_tasks_table.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';
import 'package:http/http.dart' as http;
import 'package:synchronized_call/synchronized_call.dart';

typedef BoxTaskCallback = void Function(BoxTaskFeign task, dynamic result, dynamic e, dynamic s);

class BoxTaskAspect extends BoxTaskInterceptor {
  void Function(List<BoxUniqueRow> loopTasks, FutureQueue futureQueue)? mLoopBegin;
  void Function(dynamic e, dynamic s)? mLoopEnd;
  Future<bool> Function(BoxTaskFeign task)? mTaskBegin;
  void Function(BoxTaskFeign task)? mTaskEnd;

  @override
  void loopBegin(List<BoxUniqueRow> loopTasks, FutureQueue futureQueue) => mLoopBegin?.call(loopTasks, futureQueue);

  @override
  void loopEnd(e, s) => mLoopEnd?.call(e, s);

  @override
  Future<bool> taskBegin(BoxTaskFeign task) async => (await mTaskBegin?.call(task)) ?? true;

  @override
  void taskEnd(BoxTaskFeign task) => mTaskEnd?.call(task);
}

/// 缓存任务 管理者
class BoxTasksManager {
  static const String TAG = 'BoxTasksManager';

  static String iBoxTaskKey(String type, String id) => '${type}@${id}';

  /// Listeners. Note: all tasks will be notified, so you should filter the task type and id you are interested in.
  static List<BoxTaskCallback> listeners = <BoxTaskCallback>[];

  static void addListener(BoxTaskCallback listener) => listeners.add(listener);

  static void removeListener(BoxTaskCallback listener) => listeners.remove(listener);

  static void notifyListeners(BoxTaskFeign task, dynamic result, dynamic e, dynamic s) {
    Future.microtask(() {
      for (int i = 0; i < listeners.length; i++) {
        (listeners[i])(task, result, e, s);
      }
    });
  }

  /// Completer. For implementation of task done future
  static Map<String, Completer<BoxTaskResult>> _completers = {};

  static void _addCompleter(String key, Completer<BoxTaskResult> completer) => _completers[key] = completer;

  static Completer<BoxTaskResult>? _removeCompleter(String key) => _completers.remove(key);

  /// Setting/Changing Network status
  static bool _isNetworkOk = true;

  static void setNetworkStatus(bool ok) {
    if (_isNetworkOk == false && ok == true) {
      BoxerLogger.i(TAG, 'Resume tasks loop cause network become connected.');
      BoxTasksManager.start();
    }
    _isNetworkOk = ok;
  }

  /// Tell the manager if caller doing the task now
  static List<String>? _callerDoingTasks;

  static bool isDoingByMeNow(String type, String id) {
    return _callerDoingTasks?.contains(iBoxTaskKey(type, id)) ?? false;
  }

  static void setDoingByMeNow(String type, String id) {
    (_callerDoingTasks ??= []).add(iBoxTaskKey(type, id));
  }

  /// Tell the manager if caller done the task that caller doing before
  static Future<bool> removeDoingByMeNow(String type, String id, bool isSuccess) async {
    String taskKey = iBoxTaskKey(type, id);
    _callerDoingTasks?.remove(taskKey);
    if (isSuccess) {
      try {
        bool isRemoved = await BoxCacheTasks.instance.removeTask(taskType: type, taskId: id) == 1;
        BoxerLogger.i(TAG, 'RemoveDoingByMe result: $taskKey, $isRemoved');
        return isRemoved;
      } catch (e, s) {
        BoxerLogger.e(TAG, 'RemoveDoingByMe error: $taskKey, $e, $s');
      }
      return false;
    } else {
      BoxerLogger.i(TAG, 'Resume tasks loop cause caller cache the task that he just failed for $taskKey.');
      BoxTasksManager.start();
    }
    return true;
  }

  /// Start the task looper
  static void start() {
    BoxCacheTasks.instance.start();
  }

  /// 初始化: 使用存储的表、每个Type的任务如何执行
  static void init() {
    BoxCacheTasks.instance.table = BoxTableManager.cacheTableTasks;
    BoxCacheTasks.instance.doTask = (BoxTaskFeign task) async {
      BoxTaskResult? result;
      try {
        result = await BoxTasksManager._doOneTask(task);
      } catch (e, s) {
        BoxerLogger.e(TAG, 'Done doTask $task error: $e, $s');
      }

      bool isSuccess = result?.isSuccess ?? false;
      BoxerLogger.i(TAG, 'Do a task$task ${isSuccess ? 'success' : 'failed'}');

      // Refresh view and toast the status
      PageTasksTableState.refreshToastTaskDoneExecuteStatus(task, isSuccess);
      return result ?? BoxTaskResult(false, null);
    };

    BoxCacheTasks.instance.init(() {
      BoxTaskAspect interceptor = BoxTaskAspect();

      /// Do not do the HTTP task if network is disconnected
      interceptor.mLoopBegin = (loopTasks, futureQueue) {
        if (loopTasks.isEmpty) return;
        BoxerLogger.i(TAG, 'Loop will start ${loopTasks.length} tasks, removing tasks that will not be executed ...');
        if (_isNetworkOk == false) {
          loopTasks.removeWhere((e) => BoxTaskType.isHttpType(e.type));
          BoxerLogger.i(TAG, 'Network is down, after removing HTTP tasks, now count is (${loopTasks.length}) ...');
        }
        loopTasks.removeWhere((e) => BoxTasksManager.isDoingByMeNow(e.type, e.id));
        BoxerLogger.i(TAG, 'After removing CALLER DOING tasks, now count is (${loopTasks.length}) ...');
      };

      /// Notify the existed completer when the specified task is done
      interceptor.mTaskEnd = (BoxTaskFeign task) {
        () async {
          if (await BoxCacheTasks.instance.isTaskExisted(taskType: task.type, taskId: task.id)) return;
          Completer<BoxTaskResult>? completer = _removeCompleter(iBoxTaskKey(task.type, task.id));
          completer?.complete(task.result ?? BoxTaskResult(false, null));
        }();
      };
      BoxCacheTasks.instance.addInterceptor(interceptor);
    });
  }

  /// 执行单个缓存任务
  static Future<BoxTaskResult> _doOneTask(BoxTaskFeign task) async {
    BoxerLogger.d(TAG, '_doOneTask: ${task.toJson()}}');
    String taskType = task.type;

    dynamic result, error, stack;
    try {
      if (BoxTaskType.isHttpType(taskType)) {
        await Future.delayed(const Duration(milliseconds: 2 * 1000));

        Map data = task.task.data;
        String method = (data['method']?.toString() ?? 'POST').toUpperCase();
        String path = data['path']?.toString() ?? data['url']?.toString() ?? '';
        var mQuery = data['query'];
        Map<String, dynamic>? query = mQuery is Map ? Map<String, dynamic>.from(mQuery) : null;
        var mBody = data['body'];
        Map<String, dynamic>? body = mBody is Map ? Map<String, dynamic>.from(mBody) : null;

        /// switch http instance
        if (method == 'GET') {
          Uri uri = Uri.parse(path).replace(
              queryParameters: (query ?? body ?? {}).map((key, value) => MapEntry(key, value?.toString() ?? '')));
          result = await http.get(uri); // GET 请求的参数可以放在 query 或 body 中，随便
        } else if (method == 'POST') {
          Uri uri = Uri.parse(path)
              .replace(queryParameters: (query ?? {}).map((key, value) => MapEntry(key, value?.toString() ?? '')));
          result = await http.post(uri, body: body); // 但 POST 就要严格了，参数 query 请求体 body
        }

        if (kDebugMode && _isNetworkOk == false) {
          throw SocketException('connection aborted: ${task.count}');
        }

        BoxerLogger.d(TAG, '###### Response status: ${result.statusCode}, body: \n${result.body}');
        return BoxTaskResult(true, result);
      } else if (taskType == 'WAIT_ME') {
        await Future.delayed(const Duration(milliseconds: 3 * 1000));
        return BoxTaskResult(true, result);
      } else if (taskType == 'FAILED_TASK') {
        await Future.delayed(const Duration(milliseconds: 2 * 1000));
        throw const HandshakeException('❌ handshake error!');
      } else if (taskType == 'SHOULD_DO_CHECK') {
        await Future.delayed(const Duration(milliseconds: 1 * 1000));
        return BoxTaskResult(true, result);
      }
    } catch (e, s) {
      error = e;
      stack = s;
      rethrow;
    } finally {
      notifyListeners(task, result, error, stack);
    }

    BoxerLogger.w(TAG, 'execute the not supported task: $task}');
    return BoxTaskResult(false, result, error, stack);
  }

  /// 添加一个HTTP任务
  static Future<BoxTaskResult>? addHttpTask(
    String taskId,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool isBigHttp = true,
    bool isHttpPost = true,
    bool isAsyncTask = false,
    int? maxRetryCount,
    bool? isNeedFuture,
  }) {
    Map<String, dynamic> data = {'method': isHttpPost ? 'POST' : 'GET', 'path': path};
    if (body != null) data['body'] = body;
    if (query != null) data['query'] = query;
    String type = BoxTaskType.getHttpType(isBigHttp);
    BoxCacheTasks.instance.addTask(
      BoxTask(type: type, id: taskId, isAsync: isAsyncTask, data: data),
      maxCount: maxRetryCount,
    );
    if (isNeedFuture == true) {
      Completer<BoxTaskResult> completer = Completer();
      _addCompleter(iBoxTaskKey(type, taskId), completer);
      return completer.future;
    }
    return null;
  }

  static void setHttpTaskDoingByMeNow(String taskId, {bool isBigHttp = true}) {
    setDoingByMeNow(BoxTaskType.getHttpType(isBigHttp), taskId);
  }

  static void removeHttpTaskDoingByMeNow(String taskId, bool isSuccess, {bool isBigHttp = true}) {
    removeDoingByMeNow(BoxTaskType.getHttpType(isBigHttp), taskId, isSuccess);
  }
}

class BoxTaskType {
  static const String HTTP_SMALL = "HTTP_SMALL";
  static const String HTTP_BIGGER = "HTTP_BIGGER";

  static bool isHttpType(String type) => type == BoxTaskType.HTTP_BIGGER || type == BoxTaskType.HTTP_SMALL;

  static String getHttpType([bool isBigHttp = true]) => isBigHttp ? BoxTaskType.HTTP_BIGGER : BoxTaskType.HTTP_SMALL;
}
