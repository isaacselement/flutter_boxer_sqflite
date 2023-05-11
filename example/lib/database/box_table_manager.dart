import 'package:example/database/box_cache_table.dart';

/// Table Manager
class BoxTableManager {
  static const String kNAME_BIZ_COMMON = 'cache_biz_common';
  static const String kNAME_BIZ_STUDENTS = 'cache_biz_student';

  static BoxCacheTable bizCacheTable = BoxCacheTable(tableName: kNAME_BIZ_COMMON);
  static BoxCacheTable bizCacheStudent = BoxCacheTable(tableName: kNAME_BIZ_STUDENTS);
}
