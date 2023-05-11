# flutter_boxer_sqflite

[![pub package](https://img.shields.io/pub/v/flutter_boxer_sqflite.svg)](https://pub.dev/packages/flutter_boxer_sqflite)

A Wrapper of package `sqflite`, support easy usage on `query/insert/update/delete` and `batch/transaction`

## Initialize

    ````
    # Create a boxer instance (generic a single instance)
    BoxerDatabase boxer = BoxerDatabase(version: version, name: 'database.db');
    
    # Register the tables
    boxer.registerTable(BoxTableManager.bizCacheTable);
    boxer.registerTable(BoxTableManager.bizCacheStudent);
    
    # Open the database establish connection
    await boxer.open();
    ````

## How to use

* Look out API of the three class `BoxerDatabase` and `BoxerTableBase` & its subclass `BoxerTableTranslator`
* Run `example/lib/main.dart` on mobile device or PC for more example usage.

## Features and bugs

Please feel free to:
request new features and bugs at the [issue tracker][tracker]



[tracker]: https://github.com/isaacselement/flutter_boxer_sqflite/issues