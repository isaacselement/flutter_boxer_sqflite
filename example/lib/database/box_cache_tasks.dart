import 'dart:async';

import 'package:example/database/box_cache_table.dart';
import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';
import 'package:synchronized_call/synchronized_call.dart';

enum BoxTaskKind { SYNC, ASYNC }

enum BoxTaskStatus { PENDING, EXECUTING }

class BoxCacheTaskTable extends BoxCacheTable {
  BoxCacheTaskTable({required String tableName}) : super(tableName: tableName);

  static const String kCOLUMN_KIND = 'KIND'; // 代表任务是同步异步, 0: sync, 1: async
  static const String kCOLUMN_STATUS = 'STATUS'; // 代表任务状态, 0: pending, 1: executing
  static const String kCOLUMN_PRIORITY = 'PRIORITY'; // 代表任务优先级, 数值越大优先级越高, 默认为0

  @override
  String? get createTableSpecification {
    String? sql = super.createTableSpecification;
    if (sql == null) return null;
    List<String> strings = sql.split(BoxerTableBase.SEPARATOR);

    /// insert tow extra columns
    String? createSql = strings.firstSafe;
    List<String>? columns = createSql?.split(',');
    if ((columns != null) && (columns.length > 5)) {
      columns.insert(4, '${BoxCacheTaskTable.kCOLUMN_KIND} INTEGER NOT NULL DEFAULT 0');
      columns.insert(5, '${BoxCacheTaskTable.kCOLUMN_STATUS} INTEGER NOT NULL DEFAULT 0');
      columns.insert(6, '${BoxCacheTaskTable.kCOLUMN_PRIORITY} INTEGER NOT NULL DEFAULT 0');
      createSql = columns.join(',');
      strings.removeAt(0);
      strings.insert(0, createSql);
      sql = strings.join(BoxerTableBase.SEPARATOR);
    }
    return sql;
  }
}

class BoxUniqueRow {
  final String type, id;
  final BoxTaskKind kind;

  BoxUniqueRow({required this.type, required this.id, required this.kind});

  @override
  String toString() => '($type: $id${kind == BoxTaskKind.ASYNC ? ' A' : ''})';
}

class BoxTask extends BoxUniqueRow {
  final Map data;

  BoxTask({required String type, required String id, bool? isAsync, required this.data})
      : super(type: type, id: id, kind: isAsync == true ? BoxTaskKind.ASYNC : BoxTaskKind.SYNC);

  Map toJson() => {'type': type, 'id': id, 'kind': kind.index, 'data': data};

  factory BoxTask.fromJson(Map e) => BoxTask(
      type: e['type'] ?? '', id: e['id'] ?? '', isAsync: e['kind'] == BoxTaskKind.ASYNC.index, data: e['data'] ?? {});
}

class BoxTaskFeign {
  final BoxTask task;

  /// time: the task added time
  final int time;

  /// count & maxCount: task execute number/max number of retries
  /// firstTime & lastTime: task execute first/last execute time; lastStatus: 0 not executed, 1 failed, 200 success
  int count = 0, maxCount = 0, firstTime = 0, lastTime = 0, lastStatus = 0;

  String get type => task.type;

  String get id => task.id;

  BoxTaskKind get kind => task.kind;

  BoxTaskFeign({required this.task, required this.time});

  Map toJson() => {
        'task': task.toJson(),
        'time': time,
        'count': count,
        'maxCount': maxCount,
        'firstTime': firstTime,
        'lastTime': lastTime,
        'lastStatus': lastStatus,
      };

  factory BoxTaskFeign.fromJson(Map e) => BoxTaskFeign(task: BoxTask.fromJson(e['task']), time: e['time'] ?? nowMillis)
        ..count = e['count'] ?? 0
        ..maxCount = e['maxCount'] ?? 0
        ..firstTime = e['firstTime'] ?? 0
        ..lastTime = e['lastTime'] ?? 0
        ..lastStatus = e['lastStatus'] ?? 0
      //
      ;

  factory BoxTaskFeign.create(BoxTask task, {int maxCount = 0}) =>
      BoxTaskFeign(task: task, time: nowMillis)..maxCount = maxCount;

  bool isSame(BoxTaskFeign? other) => type == other?.type && id == other?.id && time == other?.time;

  static int get nowMillis => DateTime.now().millisecondsSinceEpoch;

  @override
  String toString() => '$task'.replaceAll('(', '[').replaceAll(')', ']');

  /// execute result
  BoxTaskResult? result;
}

class BoxTaskResult {
  final bool isSuccess;
  final Object? data;
  final dynamic error, stack;

  BoxTaskResult(this.isSuccess, this.data, [this.error, this.stack]);

  @override
  String toString() => '$isSuccess, $data, $error';
}

abstract class BoxTaskInterceptor {
  void loopBegin(List<BoxUniqueRow> loopTasks, FutureQueue futureQueue);

  void loopEnd(dynamic e, dynamic s);

  Future<bool> taskBegin(BoxTaskFeign task);

  void taskEnd(BoxTaskFeign task);

  /// Util methods
  static void callLoopBegin(List<BoxTaskInterceptor> list, List<BoxUniqueRow> loopTasks, FutureQueue futureQueue) {
    for (int i = 0; i < list.length; i++) {
      list[i].loopBegin(loopTasks, futureQueue);
    }
  }

  static void callLoopEnd(List<BoxTaskInterceptor> list, dynamic e, dynamic s) {
    for (int i = 0; i < list.length; i++) {
      list[i].loopEnd(e, s);
    }
  }

  static Future<bool> callPerBegin(List<BoxTaskInterceptor> list, BoxTaskFeign current) async {
    // return false if one of interceptors want to skip a task
    for (int i = 0; i < list.length; i++) {
      if ((await list[i].taskBegin(current)) == false) {
        return false;
      }
    }
    return true;
  }

  static void callPerEnd(List<BoxTaskInterceptor> list, BoxTaskFeign task) {
    for (int i = 0; i < list.length; i++) {
      list[i].taskEnd(task);
    }
  }
}

/// Cache tasks base on [BoxCacheTable]
class BoxCacheTasks {
  static const String TAG = 'BoxCacheTasks';

  /// Required, the table for persistent tasks
  BoxCacheTable table;

  BoxCacheTable get mTable => table;

  /// Required, tell tasks looper how to do a task
  late FutureOr<BoxTaskResult> Function(BoxTaskFeign task) doTask;

  /// Interceptors. Tell tasks looper if/whether to execute/do the next/current task or not
  List<BoxTaskInterceptor> interceptors = [];

  void addInterceptor(BoxTaskInterceptor interceptor) => interceptors.add(interceptor);

  void removeInterceptor(BoxTaskInterceptor interceptor) => interceptors.remove(interceptor);

  void _doInterceptorsOnLoopBegin(List<BoxUniqueRow> loopTasks, FutureQueue futureQueue) {
    BoxTaskInterceptor.callLoopBegin(interceptors, loopTasks, futureQueue);
  }

  void _doInterceptorsOnLoopEnd(dynamic e, dynamic s) {
    BoxTaskInterceptor.callLoopEnd(interceptors, e, s);
  }

  Future<bool> _doInterceptorsOnPerBegin(BoxTaskFeign current) async {
    return await BoxTaskInterceptor.callPerBegin(interceptors, current);
  }

  void _doInterceptorsOnPerEnd(BoxTaskFeign? task) {
    if (task == null) return;
    BoxTaskInterceptor.callPerEnd(interceptors, task);
  }

  /// Optional, assign the properties [logger/fatalLogger/maker] to this logger instance
  BoxerLoggerInstance logger = BoxerLogger.instance; // BoxerLoggerInstance();

  /// Optional, max execute task retry count
  int kRetryLimitCount = 10;

  BoxCacheTasks(this.table) {
    table.setModelTranslator<BoxTaskFeign>(
      (Map e) => BoxTaskFeign.fromJson(e),
      (BoxTaskFeign e) => e.toJson(),
      (BoxTaskFeign e) => {BoxCacheTable.kCOLUMN_ITEM_TYPE: e.type, BoxCacheTable.kCOLUMN_ITEM_ID: e.id},
    );
  }

  void start() {
    CallLock.got<InclusiveLock>(mTable.tableName).call(__start__);
  }

  void resume() {
    isManuallyStop = false;
    start();
  }

  void stop() {
    autoStartInterval = 0;
    isManuallyStop = true;
    doingTasks?.clear();
    doingTasks = null;
  }

  /// 添加一个任务
  /// same [taskType] and [taskId] add multiple times is allowed, cache will just keep the newest one
  Future<void> addTask(BoxTask task, {int? priority, int? maxCount}) async {
    BoxTaskFeign feign = BoxTaskFeign.create(task, maxCount: maxCount ?? kRetryLimitCount);
    String itemId = feign.id; // same as task.id
    String itemType = feign.type; // same as task.type
    /// reset here, as is known to all: do remove then do add
    await mTable.reset(
      type: itemType,
      itemId: itemId,
      value: feign.toJson(),
      isReThrow: true,
      // add two more column 'kind' & 'priority' and their values
      translator: (e, s) {
        return {
          BoxCacheTable.kCOLUMN_ITEM_ID: itemId,
          BoxCacheTable.kCOLUMN_ITEM_TYPE: itemType,
          BoxCacheTaskTable.kCOLUMN_KIND: task.kind.index,
          BoxCacheTaskTable.kCOLUMN_PRIORITY: priority ?? 0,
        };
      },
    );

    /// invoke start anyway when add a new task
    autoStartInterval = 0;
    start();
  }

  /// 任务是否存在
  Future<bool> isTaskExisted({required String taskType, required String taskId}) async {
    return (await getTask(taskType: taskType, taskId: taskId)) != null;
  }

  /// 获取一个任务
  Future<BoxTaskFeign?> getTask({required String taskType, required String taskId}) async {
    return await mTable.one<BoxTaskFeign>(
      type: taskType,
      itemId: taskId,
      fromJson: (e) => BoxTaskFeign.fromJson(e),
      isReThrow: true,
    );
  }

  /// 获取所有任务
  Future<List<BoxUniqueRow>> getAllTasks() async {
    BoxerQueryOption op =
        BoxerQueryOption.e(column: BoxCacheTaskTable.kCOLUMN_STATUS, value: BoxTaskStatus.PENDING.index);
    String orderBy = ''
        '${BoxCacheTaskTable.kCOLUMN_PRIORITY} DESC,' // 优先级越高越先执行
        '${BoxCacheTable.kCOLUMN_UPDATE_TIME} ASC,' // 同等优先级，则越早更新过/从没更新过的 越先执行
        '${BoxCacheTable.kCOLUMN_CREATE_TIME} DESC,' // 同等优先级 及 从没更新过的[或更新时间一样(极少)]，则最新创建的 越先执行
        '';
    op.orderBy = orderBy.trim().removeEndWith(',');
    // 为了省些内存，不把 数据 全选择出来了, 创建类 [BoxUniqueRow] 出来只存储 [type] 和 [id]
    op.columns = [BoxCacheTable.kCOLUMN_ITEM_TYPE, BoxCacheTable.kCOLUMN_ITEM_ID, BoxCacheTaskTable.kCOLUMN_KIND];
    // 自己转化所有'外层'数据的，用 [mQueryTo] 方法
    List<BoxUniqueRow?> list = await mTable.mQueryTo<BoxUniqueRow?>(
      options: op,
      translator: (Map<String, Object?> e) {
        String? type = e[BoxCacheTable.kCOLUMN_ITEM_TYPE]?.toString();
        String? id = e[BoxCacheTable.kCOLUMN_ITEM_ID]?.toString();
        int? index = int.tryParse(e[BoxCacheTaskTable.kCOLUMN_KIND]?.toString() ?? '');
        if (type == null || id == null || index == null) return null;
        BoxTaskKind kind =
            index < 0 || index >= BoxTaskKind.values.length ? BoxTaskKind.SYNC : BoxTaskKind.values[index];
        return BoxUniqueRow(type: type, id: id, kind: kind);
      },
    );
    List<BoxUniqueRow> results = List<BoxUniqueRow>.from(list.where((e) => e != null).toList());
    // 倒序排序, 把 ASYNC 异步任务的放到前面，则会一次性执行异步任务，然后同步任务一个等一个完成后执行
    results.sort((a, b) => b.kind.index.compareTo(a.kind.index));
    return results;
  }

  /// 更新一个任务
  Future<int> updateTask(BoxTaskFeign feign) async {
    return await mTable.modify(type: feign.type, itemId: feign.id, value: feign.toJson(), isReThrow: true);
  }

  /// 删除一个任务
  Future<int> removeTask({required String taskType, required String taskId}) async {
    return await mTable.remove(type: taskType, itemId: taskId, isReThrow: true);
  }

  /// Auto trigger [start] scenario count, also use as recursive throttle interval
  int autoStartInterval = 0;

  /// Start the tasks looper
  List<BoxUniqueRow>? doingTasks; // for control the local looping tasks variable
  bool isManuallyStop = false; // flag for using in stop() & resume() method
  bool isStarted = false;

  Future<void> __start__() async {
    if (isManuallyStop) {
      logger.i(TAG, "💚 Tasks job has been manually stopped.");
      return;
    }
    if (isStarted) return;
    isStarted = true;

    dynamic error, stack;
    FutureQueue? futuresQueue;

    try {
      /// 事先拿出任务列表，避免在执行过程中有新任务插入，最近更新过的放在列表更后，按更新时间ASC排序
      List<BoxUniqueRow> tasks = await getAllTasks();
      doingTasks = tasks;
      logger.i(TAG, "❎ --- TASKS START: ${tasks.length} ---");

      futuresQueue = FutureQueue();
      _doInterceptorsOnLoopBegin(tasks, futuresQueue);
      int count = tasks.length;

      /// Return if tasks is empty
      if (count <= 0) {
        autoStartInterval = 0;
        return;
      }

      /// 做完一轮任务后，再次检查是否有新任务插入/或有任务失败了，有则再次执行一轮任务
      futuresQueue.addListener(() async {
        autoStartInterval++;
        logger.i(TAG, "🟢 All done, recursive [start] checking has new/failed task or not? ${autoStartInterval}s");
        if (autoStartInterval > 60) {
          logger.mark(tag: '__tasks_recursive_a_lot__', object: autoStartInterval);
          logger.w(TAG, "Recursive start tasks a lot: $autoStartInterval");
        }
        await Future.delayed(Duration(seconds: autoStartInterval));

        /// invoke start again
        start();
      });

      if (count > 50) {
        logger.mark(tag: '__tasks_accumulated_a_lot__', object: count);
        logger.w(TAG, "Too many tasks have been accumulated: $count");
      }

      /// important! check the length every time, cause tasks will be removed during the loop or [stop] by caller
      while (tasks.isNotEmpty && doingTasks != null) {
        try {
          logger.i(TAG, "Start, left in the task queue count is: ${tasks.length}");
          BoxUniqueRow row = tasks.removeAt(0);

          /// execute task
          Future<void> future = execute(row);
          futuresQueue.enqueue(future);

          /// Wait the sync task done, all async tasks all were sorted in advance and had been invoked
          if (row.kind == BoxTaskKind.SYNC) {
            await future;
          }
        } catch (e, s) {
          logger.e(TAG, "Do a tasks error: $e, $s");
          logger.reportFatal(e, s);
        }
      }
    } catch (e, s) {
      error = e;
      stack = s;
      logger.e(TAG, "Start tasks error: $e, $s");
      logger.reportFatal(e, s);
    } finally {
      isStarted = false;
      logger.i(TAG, "✅ --- TASKS DONE ---");
      futuresQueue?.wait();

      _doInterceptorsOnLoopEnd(error, stack);
    }
  }

  /// execute one task
  Future<void> execute(BoxUniqueRow one) async {
    String taskType = one.type;
    String taskId = one.id;

    /// 因为缓存或延时, 做任务前先检查确保一下此任务还在任务表不, 为了拿出其最新任务数据 又或者 为了确保期间此任务没有被移除
    BoxTaskFeign? f = await getTask(taskType: taskType, taskId: taskId);
    if (f == null) {
      logger.i(TAG, "🚫Abort execute operation, task $one has been deleted, step out.");
      return;
    }
    if ((await getTaskStatus(f)) == BoxTaskStatus.EXECUTING) {
      logger.i(TAG, "🚫Abort execute operation, task $f is executing, step out.");
      return;
    }

    /// invoke interceptors for checking do next task or not, also you can wait an interval time in it.
    if (await _doInterceptorsOnPerBegin(f) == false) {
      logger.i(TAG, "No need to do a task $f by check false, so continue...");
      return;
    }

    BoxTaskFeign feign = f;

    /// Update to task to db
    await updateTaskStatus(feign, BoxTaskStatus.EXECUTING);

    BoxTaskResult result;
    try {
      /// Call handleTask, task success or not is determined by Caller
      result = await doTask(feign);
    } catch (e, s) {
      logger.e(TAG, "Caller handle task error: $e, $s");
      result = BoxTaskResult(false, null, e, s);
    }
    feign.result = result;
    bool isSuccess = result.isSuccess;
    logger.i(TAG, "Done a task $feign ${isSuccess ? 'success' : 'failed'}");

    /// Update to task to db
    await updateTaskStatus(feign, BoxTaskStatus.PENDING);

    feign.count = feign.count + 1;

    /// 检查是否超出重试次数, 若超出重试次数, 则删除任务
    int limitCount = feign.maxCount > 0 ? feign.maxCount : kRetryLimitCount;
    bool isExceedLimit = feign.count > limitCount;
    if (isExceedLimit) {
      Map object = {...feign.toJson(), 'limitCount': limitCount, 'result': result.toString()};
      logger.mark(tag: '__task_execute_exceeded_limit__', object: object);
      logger.w(TAG, "Task retry count exceeded: $object");
    }

    Future<bool> doRemoveTask(BoxTaskFeign feign) async {
      logger.i(TAG, "Removing task[$taskType: $taskId] ...");
      try {
        /// 先检查确保一下当前任务表里的任务是这次做完的任务，以免期间有新插入(一次/多次)相同任务ID的任务
        BoxTaskFeign? newest = await getTask(taskType: taskType, taskId: taskId);

        /// 不是同一个任务，已经有新的相同任务Type & Id的任务插入了，此时直接返回
        if (!feign.isSame(newest)) {
          logger.i(TAG, "🚫Abort remove operation, cause differ with newest task[$taskType: $taskId].");
          return false;
        }
      } catch (e, s) {
        logger.e(TAG, "Get task on remove phase error: $e, $s");
        logger.reportFatal(e, s);
      }

      bool isRemoved = false;
      try {
        /// remove the completed task from db
        int removedCount = await removeTask(taskType: taskType, taskId: taskId);
        isRemoved = removedCount == 1;
        logger.i(TAG, "Remove the task[$taskType: $taskId] ($removedCount) ${isRemoved ? 'success' : 'failed'}");
      } catch (e, s) {
        logger.e(TAG, "Remove task with error: $e, $s");
        logger.reportFatal(e, s);
      }
      return isRemoved;
    }

    try {
      /// Remove if success and if the same task with db
      if ((isSuccess || isExceedLimit) && (await doRemoveTask(feign))) {
        return;
      }

      /// Update to task info to db
      feign.lastTime = DateTime.now().millisecondsSinceEpoch;
      if (feign.firstTime == 0) feign.firstTime = feign.lastTime;
      feign.lastStatus = isSuccess ? 200 : 1;
      await updateTask(feign);
    } catch (e, s) {
      logger.e(TAG, "Task update executed info error: $e, $s");
      logger.reportFatal(e, s);
    } finally {
      /// invoke interceptors for caller checking the task is removed or not
      _doInterceptorsOnPerEnd(feign);
    }
  }

  /// Util methods
  Future<void> updateTaskStatus(BoxTaskFeign feign, BoxTaskStatus status) async {
    try {
      BoxerQueryOption op = mTable.getOptions(type: feign.type, itemId: feign.id);
      await mTable.setColumnValue(BoxCacheTaskTable.kCOLUMN_STATUS, status.index, options: op);
    } catch (e, s) {
      logger.e(TAG, "Task update status info error: $e, $s");
      logger.reportFatal(e, s);
    }
  }

  Future<BoxTaskStatus> getTaskStatus(BoxTaskFeign feign) async {
    try {
      BoxerQueryOption op = mTable.getOptions(type: feign.type, itemId: feign.id);
      Object? index = await mTable.getColumnValue(BoxCacheTaskTable.kCOLUMN_STATUS, options: op);
      return index == BoxTaskStatus.EXECUTING.index ? BoxTaskStatus.EXECUTING : BoxTaskStatus.PENDING;
    } catch (e, s) {
      logger.e(TAG, "Task get status info error: $e, $s");
      logger.reportFatal(e, s);
    }
    return BoxTaskStatus.PENDING;
  }
}
