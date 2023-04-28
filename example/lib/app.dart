import 'package:example/common/widget/box_tab_bar.dart';
import 'package:example/page/all_tables_page.dart';
import 'package:example/page/sqlite_master_paget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';
import 'package:flutter_dialog_shower/flutter_dialog_shower.dart';

class App extends StatefulWidget {
  @override
  AppState createState() => AppState();
}

class AppState extends State<App> with SingleTickerProviderStateMixin {
  static late BuildContext appContext;

  TabController? tabController;

  List<String> get tabTitles => ['all tables', 'sqlite_master'];

  List<Widget> get tabPages => [AllTablesPage(), SqliteMasterPage()];

  @override
  void initState() {
    super.initState();
    initTabController(tabTitles.length);
  }

  @override
  void dispose() {
    disposeTabController();
    super.dispose();
  }

  void initTabController(int length) {
    if (tabController == null || tabController?.length != length) {
      disposeTabController();
      tabController = TabController(initialIndex: 0, length: length, vsync: this);
      tabController!.addListener(onEventSwitchTab);
    }
  }

  void disposeTabController() {
    tabController?.removeListener(onEventSwitchTab);
    tabController?.dispose();
    tabController = null;
  }

  void onEventSwitchTab() {
    if (mounted) {}
  }

  @override
  Widget build(BuildContext context) {
    appContext = context;
    BxLoG.d('--------->>>>> App Rebuild!!!');

    SizesUtils.init(context);
    DialogShower.init(context);
    OverlayShower.init(context);
    DialogWrapper.centralOfShower ??= (DialogShower shower, {Widget? child}) {
      shower
        // null indicate that: dismiss keyboard first while keyboard is showing, else dismiss dialog immediately
        ..barrierDismissible = null
        ..containerShadowColor = Colors.grey
        ..containerShadowBlurRadius = 20.0
        ..containerBorderRadius = 10.0;
    };

    return Material(
      color: Colors.white,
      child: Column(
        children: [
          /// Tab pages
          Expanded(child: TabBarView(children: tabPages, controller: tabController)),

          /// Tab bars
          Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.grey.withAlpha(128), blurRadius: 10)],
              border: Border(top: BorderSide(width: 1, color: Colors.grey.withAlpha(32))),
            ),
            child: BoxTabBar(titles: tabTitles, tabController: tabController),
          ),
        ],
      ),
    );
  }
}
