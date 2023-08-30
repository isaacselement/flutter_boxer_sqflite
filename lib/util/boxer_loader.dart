import 'dart:async';

import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';

class BoxerLoader<T> {
  static const String TAG = 'BoxerLoader';

  /// Whether to enable the cache feature
  bool isEnableCache = true;

  void Function(T value) howToUpdateCache;
  void Function(T value, bool isFromCache) howToUpdateView;

  /// Instance Error callback for [requestFuture] and [cacheFuture]
  BoxerLoadErrorCallback? onLoadError;

  BoxerLoader({required this.howToUpdateCache, required this.howToUpdateView, this.onLoadError});

  /// Unless [loadRequestFuture] is completed before [loadCacheFuture],
  /// both [loadRequestFuture] and [loadCacheFuture] will call [howToUpdateView] to update the view
  ///
  /// [loadCacheFuture] itself is a cache so there is no need to update the cache
  /// [loadRequestFuture] will call [howToUpdateCache] to update the cache after completion
  ///
  /// [loadCacheFuture] and [loadRequestFuture] can explicitly pass null value
  /// so as to ensure that the caller knows that he has explicitly send a null value
  ///
  /// for there is indeed such scenarios:
  /// 1. [loadRequestFuture] is null, just want to reload the cache data, and update the view
  /// 2. [loadCacheFuture] is null, just need the requested data to update view and cache, but no need to read the cache
  Future<T?> getData({
    required Future<T>? loadCacheFuture,
    required Future<T>? loadRequestFuture,
    BoxerLoadErrorCallback? onLoadError,
  }) {
    Future<T>? f1;
    Future<T>? f2;

    List<dynamic> results = [Null, Null];
    bool isRequestSuccess = false;
    () {
      f1 = loadRequestFuture;
      loadRequestFuture?.then((value) {
        results.first = value;
        isRequestSuccess = true;

        /// Update UI And Cache
        update(value, isValueFromCache: false, isOnlyUpdateView: false);
      }).onError((e, s) {
        (onLoadError ?? this.onLoadError)?.call(e, s, BoxerLoadType.REQUEST);
      });

      if (isEnableCache == false) return;

      f2 = loadCacheFuture;
      loadCacheFuture?.then((value) {
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
        (onLoadError ?? this.onLoadError)?.call(e, s, BoxerLoadType.CACHE);
      });
    }();

    /// For fallback to the caller, using a completer to return the fallback future.
    Completer<T?> wholeCompleter = Completer();
    List<Future<T>> futures = [];
    if (f1 != null) futures.add(f1!);
    if (f2 != null) futures.add(f2!);
    if (futures.length > 1) {
      futures.first.then((value) {
        // if the first future request is ok, then we can complete the whole completer
        wholeCompleter.complete(value);
      }).onError((e, s) {
        // if the first future has error, then we have to wait for the second future
      });
    }
    T? getValue() => results.first != Null ? results.first as T? : (results.last != Null ? results.last as T? : null);
    Future.wait(futures).then((value) {
      if (wholeCompleter.isCompleted) return;
      wholeCompleter.complete(getValue());
    }).onError((e, s) {
      if (wholeCompleter.isCompleted) return;
      wholeCompleter.complete(getValue());
    });

    return wholeCompleter.future;
  }

  void update(T value, {bool isValueFromCache = false, bool isOnlyUpdateView = false}) {
    /// Update to UI
    howToUpdateView(value, isValueFromCache);

    /// Need to update cache or not?
    if (isOnlyUpdateView == true) return;
    if (isEnableCache == false) return;

    /// Update to cache
    howToUpdateCache(value);
  }
}

enum BoxerLoadType { CACHE, REQUEST }

typedef BoxerLoadErrorCallback = Function(dynamic error, dynamic stack, BoxerLoadType type);
