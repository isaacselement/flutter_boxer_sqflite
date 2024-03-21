# flutter_boxer_sqflite

[![pub package](https://img.shields.io/pub/v/flutter_boxer_sqflite.svg)](https://pub.dev/packages/flutter_boxer_sqflite)

Actually I am a `dart` package :)

A Wrapper of package `sqflite`, support easy usage on `query/insert/update/delete` and `batch/transaction`

## Features
- Easy to `save/update` your variational models without create different struct tables
- Easy to transform object between json/map model type using `toJson/fromJson`
- Easy to get/set `bool`, `int`, `double`, `string` etc from/to database
- Offered the cache policy to you: if the request has not yet been returned, the cache will be used first.

## How to use
### Initialize

    ````
    # Create a boxer instance (generally it's a single instance)
    BoxerDatabase boxer = BoxerDatabase(version: version, name: 'database.db');
    
    # Register the tables
    boxer.registerTable(BoxTableManager.cacheTableCommon);
    boxer.registerTable(BoxTableManager.cacheTableStudents);
    
    # Open the database establish connection
    await boxer.open();
    ````
    
    
    // Then use the api of table instance such as: get<T>/set<T>/list<T>/query<T>/delete<T> ...

<img src="https://github.com/isaacselement/flutter_boxer_sqflite/blob/master/example/screenshots/20240322-213352.gif?raw=true" width="100%">


## About try-catch

* `Boxer` sql api not wrapped by `try-catch` block, so caller should handle exceptions by yourself, upload to `Sentry` etc.
  But the `BoxCacheTable` in the example all open api are surround `try-catch` and feel free to use it.
* `Boxer` catch some fatal error, so caller can handle these error log using properties `logger` & `onFatalError` of `BoxerLogger`.

## For windows & linux

    Just uncomment the codes under `/// For windows & linux` comments, there are 3 occurrences.

## More demostrations

Run `example/lib/main.dart` on mobile device or PC for more example usage.

## Features and bugs

Please feel free to:
request new features and bugs at the [issue tracker][tracker]



[tracker]: https://github.com/isaacselement/flutter_boxer_sqflite/issues