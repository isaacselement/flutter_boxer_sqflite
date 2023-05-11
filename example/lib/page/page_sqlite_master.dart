import 'package:example/database/box_database_manager.dart';
import 'package:example/widget/table_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dialog_shower/flutter_dialog_shower.dart';
import 'package:synchronized_call/synchronized_call.dart';

class PageSqliteMaster extends StatefulWidget {
  PageSqliteMaster({Key? key}) : super(key: key);

  @override
  PageSqliteMasterState createState() => PageSqliteMasterState();
}

class PageSqliteMasterState extends State<PageSqliteMaster> with WidgetsBindingObserver {
  Widget allTableWidgets = Column();

  Map<String, ScrollController> listScrollControllers = {};

  @override
  void initState() {
    super.initState();
    Boxes.getWidgetsBinding().addObserver(this);
    refresh();
  }

  @override
  void dispose() {
    Boxes.getWidgetsBinding().removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    refreshTablesUIOnly();
  }

  Future<void> refresh() async {
    await refreshDataSource();
    refreshTablesUIOnly();
  }

  List<Map<String, dynamic>> datasource = [];

  Future<void> refreshDataSource() async {
    await CallLock.get('refresh_datasource').call(() async => await _refreshDataSourceRaw());
  }

  Future<void> _refreshDataSourceRaw() async {
    await BoxDatabaseManager.init();
    datasource.clear();

    Map<String, dynamic>? map = {};

    /// show sqlite_master
    String tableName = 'sqlite_master';
    List<Map<String, Object?>> rowsResults =
        await BoxDatabaseManager.boxer.database.rawQuery("SELECT * FROM $tableName");
    map[TableView.keyTblName] = tableName;
    map[TableView.keyTblColumns] = ['type', 'name', 'tbl_name', 'rootpage', 'sql'];
    map[TableView.keyTblRowCount] = rowsResults.length;
    map[TableView.keyTblRowResults] = rowsResults;

    datasource.add(map);
    listScrollControllers[tableName] ??= ScrollController();
  }

  Future<void> refreshTablesUIOnly() async {
    List<Widget> oneTableColumnChildren = [];
    for (int i = 0; i < datasource.length; i++) {
      Map<String, dynamic> map = datasource[i];
      String tableName = map[TableView.keyTblName];

      Widget oneTableWidget = TableView(
        tableName: tableName,
        columnNames: List<String>.from(map[TableView.keyTblColumns]),
        rowsCount: map[TableView.keyTblRowCount],
        rowsResults: List<Map<String, Object?>>.from(map[TableView.keyTblRowResults]),
        scrollController: listScrollControllers[tableName],
        height: 600,
      );
      oneTableColumnChildren.add(oneTableWidget);
    }

    oneTableColumnChildren.add(SizedBox(height: 38));
    allTableWidgets = Column(children: oneTableColumnChildren);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          allTableWidgets,
        ],
      ),
    );
  }
}
