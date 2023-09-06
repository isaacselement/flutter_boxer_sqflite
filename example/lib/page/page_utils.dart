import 'package:example/database/box_cache_handler.dart';
import 'package:example/database/box_cache_table.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';
import 'package:flutter_dialog_shower/flutter_dialog_shower.dart';

class PageUtils extends StatefulWidget {
  PageUtils({Key? key}) : super(key: key);

  @override
  PageUtilsState createState() => PageUtilsState();
}

class PageUtilsState extends State<PageUtils> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CcAppleButton(
            title: "Query as Json Test",
            onPressed: () async {
              // BoxerQueryOption op1 = BoxerQueryOption.e(column: BoxCacheTable.kCOLUMN_ITEM_TYPE, value: 'BREAD');
              // List<Map> v1 = await BoxCacheHandler.commonTable.mQueryAsJson<Map>(options: op1);
              // print('######## mQueryAsJson >>>>> $v1');

              // BoxerQueryOption op10 = BoxerQueryOption.e(column: BoxCacheTable.kCOLUMN_ITEM_TYPE, value: 'BREAD');
              // List<List> v10 = await BoxCacheHandler.commonTable.mQueryAsJson<List>(options: op10);
              // print('######## mQueryAsJson >>>>> $v10');

              // BoxerQueryOption op11 = BoxerQueryOption.e(column: BoxCacheTable.kCOLUMN_ITEM_TYPE, value: 'BREAD');
              // List<List?> v11 = await BoxCacheHandler.commonTable.mQueryAsJson<List?>(options: op11);
              // print('######## mQueryAsJson >>>>> $v11');

              BoxerQueryOption op2 = BoxerQueryOption.e(column: BoxCacheTable.kCOLUMN_ITEM_TYPE, value: 'BREAD');
              List<Map> v2 = await BoxCacheHandler.commonTable.mQueryAsJson<Map>(options: op2);
              print('######## mQueryAsJson >>>>> $v2');
            },
          ),
        ],
      ),
    );
  }
}
