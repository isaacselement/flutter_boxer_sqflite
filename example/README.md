# Crash

    ```
    flutter: *** WARNING ***

    Invalid argument [{tagId: 0, tagName: 🩸, tagFlag: newest}, {tagId: 1, tagName: 👠, tagFlag: headline}, {tagId: 2, tagName: 🩸, tagFlag: force_read}] with type List<Map<String, Object>>.
    Only num, String and Uint8List are supported. See https://github.com/tekartik/sqflite/blob/master/sqflite/doc/supported_types.md for details
    
    This will throw an exception in the future. For now it is displayed once per type.
    
    
    2023-04-28 20:06:35.016 Boxer[9755:17143161] -[__NSDictionaryM intValue]: unrecognized selector sent to instance 0x600001feea00
    2023-04-28 20:06:35.017 Boxer[9755:17143161] *** Terminating app due to uncaught exception 'NSInvalidArgumentException', reason: '-[__NSDictionaryM intValue]: unrecognized selector sent to instance 0x600001feea00'
    *** First throw call stack:
    (
    0   CoreFoundation                      0x00007ff8067181ba __exceptionPreprocess + 242
    1   libobjc.A.dylib                     0x00007ff80623e42b objc_exception_throw + 48
    2   CoreFoundation                      0x00007ff8067b401f -[NSObject(NSObject) __retain_OA] + 0
    3   CoreFoundation                      0x00007ff8066838d7 ___forwarding___ + 1392
    4   CoreFoundation                      0x00007ff8066832d8 _CF_forwarding_prep_0 + 120
    5   sqflite                             0x0000000105de053c +[SqflitePlugin toSqlValue:] + 444
    6   sqflite                             0x0000000105de08cc +[SqflitePlugin toSqlArguments:] + 220
    7   sqflite                             0x0000000105ddf7da -[SqfliteMethodCallOperation getSqlArguments] + 138
    8   sqflite                             0x0000000105de0eff -[SqflitePlugin executeOrError:fmdb:operation:] + 143
    9   sqflite                             0x0000000105de1f9e -[SqflitePlugin insert:fmdb:operation:] + 126
    10  sqflite                             0x0000000105de258d __41-[SqflitePlugin handleInsertCall:result:]_block_invoke_2 + 109
    11  FMDB                                0x0000000105db97a6 __30-[FMDatabaseQueue inDatabase:]_block_invoke + 102
    12  libdispatch.dylib                   0x00007ff806424033 _dispatch_client_callout + 8
    13  libdispatch.dylib                   0x00007ff806431ba1 _dispatch_lane_barrier_sync_invoke_and_complete + 60
    14  FMDB                                0x0000000105db96fa -[FMDatabaseQueue inDatabase:] + 282
    15  sqflite                             0x0000000105de24d0 __41-[SqflitePlugin handleInsertCall:result:]_block_invoke + 240
    16  libdispatch.dylib                   0x00007ff806422d91 _dispatch_call_block_and_release + 12
    17  libdispatch.dylib                   0x00007ff806424033 _dispatch_client_callout + 8
    18  libdispatch.dylib                   0x00007ff8064267c4 _dispatch_queue_override_invoke + 800
    19  libdispatch.dylib                   0x00007ff806433fa2 _dispatch_root_queue_drain + 343
    20  libdispatch.dylib                   0x00007ff806434768 _dispatch_worker_thread2 + 170
    21  libsystem_pthread.dylib             0x00007ff8065c1c0f _pthread_wqthread + 257
    22  libsystem_pthread.dylib             0x00007ff8065c0bbf start_wqthread + 15
    )
    libc++abi: terminating due to uncaught exception of type NSException
    Lost connection to device.

    ```

### Ubuntu requirement
    sudo apt install build-essential llvm clang
    sudo apt install -y  libsqlite3-0 libsqlite3-dev 
    sudo apt-get install libgtk-3-dev libsecret-1-dev libsecret-1-0 libsecret-tools libjsoncpp-dev

    flutter doctor
    flutter clean