import 'dart:async';

import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';

class BoxerCacheHandler<T> {
  static const String TAG = 'BoxCacheTableHandler';

  /// Whether to enable the cache feature
  bool isEnableCache = true;

  void Function(T value) updateCache;
  void Function(T value, bool isFromCache) updateView;

  /// Instance Error callback for [requestFuture] and [cacheFuture]
  BoxerCacheHandlerErrorCallback? onLoadError;

  BoxerCacheHandler({required this.updateCache, required this.updateView, this.onLoadError});

  /// Unless [requestFuture] is completed before [cacheFuture],
  /// both [requestFuture] and [cacheFuture] will call [updateView] to update the view
  ///
  /// [requestFuture] will call [updateCache] to update the cache after completion
  /// [cacheFuture] itself is a cache so there is no need to update the cache
  ///
  /// [requestFuture] or [cacheFuture] can pass null value, required to explicitly pass null
  /// so as to ensure that the caller knows that he has explicitly passed null
  ///
  /// for there is indeed such scenarios:
  /// 1. [requestFuture] is null, just want to reload the cache data, and update the view
  /// 2. [cacheFuture] is null, just need the requested data to update view and cache, but no need to read the cache
  Future<T?> getData({
    required Future<T>? requestFuture,
    required Future<T>? cacheFuture,
    BoxerCacheHandlerErrorCallback? onError,
  }) {
    Future<T>? f1;
    Future<T>? f2;

    List<T?> results = [null, null];
    bool isRequestSuccess = false;
    () {
      f1 = requestFuture;
      requestFuture?.then((value) {
        results.first = value;
        isRequestSuccess = true;

        /// Update UI And Cache
        update(value, isValueFromCache: false, isOnlyUpdateView: false);
      }).onError((e, s) {
        (onError ?? onLoadError)?.call(e, s, BoxerCacheHandlerType.REQUEST);
      });

      if (isEnableCache == false) return;

      f2 = cacheFuture;
      cacheFuture?.then((value) {
        /// No need the cache data in this moment, cause request data already response successfully
        if (isRequestSuccess) {
          BoxerLogger.d(null, 'Request data already response, no need to use cache data');
          return;
        }
        results.last = value;

        /// Update UI Only
        update(value, isValueFromCache: true, isOnlyUpdateView: true);
      }).onError((e, s) {
        if (isRequestSuccess) {
          BoxerLogger.d(null, 'Request data already response successfully, no need to call error callback');
          return;
        }
        (onError ?? onLoadError)?.call(e, s, BoxerCacheHandlerType.CACHE);
      });
    }();

    /// TODO .... for fallback value ... To Be Optimized: We have to wait for two of them to complete
    Completer<T?> wholeCompleter = Completer();
    List<Future<T>> futures = [];
    if (f1 != null) futures.add(f1!);
    if (f2 != null) futures.add(f2!);
    Future.wait(futures).then((value) {
      if (wholeCompleter.isCompleted) return;
      wholeCompleter.complete(results.first != null ? results.first : results.last);
    }).onError((e, s) {
      if (wholeCompleter.isCompleted) return;
      wholeCompleter.complete(results.first != null ? results.first : results.last);
    });

    return wholeCompleter.future;
  }

  void update(T value, {bool isValueFromCache = false, bool isOnlyUpdateView = false}) {
    /// Update to UI
    updateView(value, isValueFromCache);

    /// Need to update cache or not?
    if (isOnlyUpdateView == true) return;
    if (isEnableCache == false) return;

    /// Update to cache
    updateCache(value);
  }
}

enum BoxerCacheHandlerType { CACHE, REQUEST }

typedef BoxerCacheHandlerErrorCallback = Function(dynamic error, dynamic stack, BoxerCacheHandlerType type);
