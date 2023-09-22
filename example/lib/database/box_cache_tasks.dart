import 'dart:async';

import 'package:example/database/box_cache_logger.dart';
import 'package:example/database/box_cache_table.dart';
import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';
import 'package:synchronized_call/synchronized_call.dart';

class BoxUniqueRow {
  final String type;
  final String id;

  BoxUniqueRow({required this.type, required this.id});

  @override
  String toString() => '[$type: $id]';
}

class BoxTask extends BoxUniqueRow {
  final Map data;

  BoxTask({required String type, required String id, required this.data}) : super(type: type, id: id);

  Map toJson() => {'type': type, 'id': id, 'data': data};

  factory BoxTask.fromJson(Map json) => BoxTask(type: json['type'], id: json['id'], data: json['data']);
}

class BoxTaskFeign {
  final int time; // the task added time
  final BoxTask task;

  int count; // the task execute retry count
  int lastTime = 0; // the task last execute time

  String get type => task.type;

  String get id => task.id;

  BoxTaskFeign({required this.task, required this.time, required this.count, required this.lastTime});

  Map toJson() => {'task': task.toJson(), 'time': time, 'count': count, 'lastTime': lastTime};

  factory BoxTaskFeign.fromJson(Map e) =>
      BoxTaskFeign(task: BoxTask.fromJson(e['task']), time: e['time'], count: e['count'], lastTime: e['lastTime']);

  @override
  String toString() => '($type: $id)';

  bool isSame(BoxTaskFeign? other) => type == other?.type && id == other?.id && time == other?.time;

  factory BoxTaskFeign.create(BoxTask task) =>
      BoxTaskFeign(time: DateTime.now().millisecondsSinceEpoch, task: task, count: 0, lastTime: 0);

  // status indicate that executed and if execute success or not
  bool? executedStatus;
}

typedef BoxTaskIfExecute = FutureOr<bool> Function(BoxTaskFeign current, BoxTaskFeign? previous);

/// Cache tasks base on [BoxCacheTable]
class BoxCacheTasks {
  static final String TAG = 'BoxCacheTasks';

  static BoxCacheTasks? _instance;

  static BoxCacheTasks get instance => _instance ??= BoxCacheTasks();

  /// Required, the table for persistent tasks
  late BoxCacheTable table;

  BoxCacheTable get mTable => table;

  /// Required, tell tasks looper how to do a task
  late FutureOr<bool> Function(BoxTaskFeign task) doTask;

  /// Optional, tell tasks looper if/whether to execute/do the task or not
  List<BoxTaskIfExecute>? shouldExecutors;

  void putIfExecutor(BoxTaskIfExecute executor) => (shouldExecutors ??= []).add(executor);

  void removeIfExecutor(BoxTaskIfExecute executor) => shouldExecutors?.remove(executor);

  /// Optional, assign the properties [logger/fatalLogger/maker] to logger, if you are interested in log/fatal error/mark
  BoxCacheLogger logger = BoxCacheLogger();

  /// Optional, max execute task retry count
  int kRetryLimitCount = 10;

  /// same [taskType] and [taskId] add multiple times is allowed, cache will just keep the newest one
  /// 添加一个任务
  Future<void> addTask(BoxTask task) async {
    /// reset is -> remove then add
    BoxTaskFeign feign = BoxTaskFeign.create(task);
    await mTable.reset(
      type: feign.type,
      itemId: feign.id,
      value: feign.toJson(),
      isReThrow: true,
    );

    /// start tasks looper
    CallLock.got<InclusiveLock>(mTable.tableName).call(start);
  }

  /// 更新一个任务
  Future<int> updateTask(BoxTaskFeign feign) async {
    return await mTable.modify(
      type: feign.type,
      itemId: feign.id,
      value: feign.toJson(),
      isReThrow: true,
    );
  }

  /// 删除一个任务
  Future<int> removeTask({required String taskType, required String taskId}) async {
    return await mTable.remove(
      type: taskType,
      itemId: taskId,
      isReThrow: true,
    );
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
    BoxerQueryOption op = BoxerQueryOption();
    op.orderBy = '${BoxCacheTable.kCOLUMN_UPDATE_TIME} ASC, ${BoxCacheTable.kCOLUMN_CREATE_TIME} DESC';
    // 为了省些内存，不把 data 全选择出来了, 创建类 [BoxUniqueRow] 出来只存储 [type] 和 [id]
    op.columns = [BoxCacheTable.kCOLUMN_ITEM_TYPE, BoxCacheTable.kCOLUMN_ITEM_ID];
    // 自己转化所有'外层'数据的，用 [mQueryTo] 方法
    List<BoxUniqueRow?> list = await mTable.mQueryTo<BoxUniqueRow?>(
      options: op,
      translator: (Map<String, Object?> e) {
        String? type = e[BoxCacheTable.kCOLUMN_ITEM_TYPE]?.toString();
        String? id = e[BoxCacheTable.kCOLUMN_ITEM_ID]?.toString();
        if (type == null || id == null) return null;
        return BoxUniqueRow(type: type, id: id);
      },
      // isReThrow: true,
    );
    List<BoxUniqueRow> result = List<BoxUniqueRow>.from(list.where((e) => e != null).toList());
    return result;
  }

  /// 任务个数
  Future<int> allTasksCount() async {
    int? count = await mTable.count(mTable.optionsWithUserRoleId(BoxerQueryOption()));
    return count ?? 0;
  }

  /// 是否有任务
  Future<bool> isHaveTasks() async {
    return (await allTasksCount()) > 0;
  }

  /// If tasks looper is started
  bool isStarted = false;

  Future<void> start() async {
    if (isStarted) return;

    try {
      isStarted = true;
      int count = await allTasksCount();
      logger.i(TAG, "❗️--- TASKS START: $count ---");
      if (count <= 0) {
        return;
      }
      if (count > 50) {
        logger.mark(tag: '__tasks_had_accumulated_a_lot__', object: count);
      }

      /// 事先拿出任务列表，避免在执行过程中有新任务插入，最近更新过的放在列表更后，按更新时间ASC排序
      List<BoxUniqueRow> tasks = await getAllTasks();

      BoxTaskFeign? current;
      BoxTaskFeign? previous;

      /// important! should check list length every time, because tasks will be removed during the loop
      while (tasks.length != 0) {
        logger.i(TAG, "Start tasks remain: ${tasks.length}");
        BoxUniqueRow row = tasks.removeAt(0);

        /// Get out the full task info
        current = await getTask(taskType: row.type, taskId: row.id);
        if (current == null) {
          logger.i(TAG, "Task[$row] has been deleted, continue.");
          continue;
        }

        /// check need to do or not, also you can wait an interval time in it.
        bool isExecuteTask = await shouldExecute(current, previous);
        if (isExecuteTask == false) {
          logger.i(TAG, "No need to do a task $current by check false, so continue...");
          continue;
        }
        bool isSuccess = await execute(current);
        previous = current;
        previous.executedStatus = isSuccess;
        logger.i(TAG, "Done a task $current ${isSuccess ? 'success' : 'failed'}");
      }
    } catch (e, s) {
      logger.e(TAG, "Start tasks error: $e, $s");
      logger.fatal(e, s);
    } finally {
      isStarted = false;
      logger.i(TAG, "❗️--- TASKS DONE ---");
    }
  }

  Future<bool> shouldExecute(BoxTaskFeign current, BoxTaskFeign? previous) async {
    List<BoxTaskIfExecute>? list = shouldExecutors;
    bool result = true;
    if (list != null) {
      for (int i = 0; i < list.length; i++) {
        if ((result = await (list[i])(current, previous)) == false) {
          break;
        }
      }
    }
    return result;
  }

  Future<bool> execute(BoxTaskFeign feign) async {
    String taskType = feign.type;
    String taskId = feign.id;

    /// 因为有延时或缓存, 做任务前, 先检查确保一下任务还在任务表不 以及 为了拿出其最新任务数据
    BoxTaskFeign? f = await getTask(taskType: taskType, taskId: taskId);
    if (f == null) {
      logger.i(TAG, "Task[$taskType: $taskId] has been deleted, step out.");
      return false;
    }
    feign = f;

    Future<void> doRemoveTask(bool isTaskSuccess) async {
      logger.i(TAG, "Removing task[$taskType: $taskId], is task success: $isTaskSuccess");
      try {
        /// 先检查确保一下当前任务表里的任务是这次做完的任务，以免期间有新插入(一次/多次)相同任务ID的任务
        BoxTaskFeign? newest = await getTask(taskType: taskType, taskId: taskId);

        /// 不是同一个任务，已经有新的相同任务Type & Id的任务插入了，此时直接返回
        if (!feign.isSame(newest)) {
          logger.i(TAG, "◉Abort remove operation, cause differ with newest task[$taskType: $taskId].");
          return;
        }
      } catch (e, s) {
        logger.e(TAG, "Get task on remove phase error: $e, $s");
        logger.fatal(e, s);
      }

      try {
        /// remove completed task from db
        int count = await removeTask(taskType: taskType, taskId: taskId);
        logger.i(TAG, "Remove the task[$taskType: $taskId] ($count) ${count == 1 ? 'success' : 'failed'}");
      } catch (e, s) {
        logger.e(TAG, "Remove task with error: $e, $s");
        logger.fatal(e, s);
      }
    }

    bool isSuccess = false;
    try {
      /// Call handleTask, task success or not is determined by Caller
      isSuccess = await doTask(feign);
      feign.lastTime = DateTime.now().millisecondsSinceEpoch;
    } catch (e, s) {
      logger.e(TAG, "Caller handle task error: $e, $s");
      logger.fatal(e, s);
    }

    if (isSuccess) {
      await doRemoveTask(true);
      return true;
    }

    /// 检查是否超出重试次数
    feign.count++;
    if (feign.count > kRetryLimitCount) {
      /// 若超出重试次数, 则删除任务
      await doRemoveTask(false);
      logger.mark(tag: '__task_executed_max_count__', object: feign.toJson());
      logger.i(TAG, "Task retry count exceeded: ${feign.toJson()}");
    } else {
      try {
        await updateTask(feign);
      } catch (e, s) {
        logger.e(TAG, "Task update retry count error: $e, $s");
        logger.fatal(e, s);
      }
    }
    return false;
  }
}
