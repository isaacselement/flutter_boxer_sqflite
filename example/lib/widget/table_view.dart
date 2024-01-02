import 'dart:convert';

import 'package:example/common/util/widget_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_boxer_sqflite/flutter_boxer_sqflite.dart';
import 'package:flutter_dialog_shower/flutter_dialog_shower.dart';

class TableView extends StatefulWidget {
  static const String keyTblName = 'mKeyTblName';
  static const String keyTblColumns = 'mKeyTblColumns';
  static const String keyTblRowCount = 'mKeyTblRowCount';
  static const String keyTblRowResults = 'mKeyTblRowResults';

  /// Table Name
  final String tableName;

  /// Column Name
  final List<String> columnNames;

  /// Row count
  final int? rowsCount;

  /// Row results
  final List<Map<String, Object?>> rowsResults;

  /// ScrollController for list view
  final ScrollController? scrollController;

  /// Widget height
  final double? height;

  /// Show sequence number
  final bool isShowSeq;

  TableView({
    Key? key,
    required this.tableName,
    required this.columnNames,
    required this.rowsCount,
    required this.rowsResults,
    this.scrollController,
    this.height = 300,
    this.isShowSeq = false,
  }) : super(key: key);

  @override
  TableViewState createState() => TableViewState();
}

class TableViewState extends State<TableView> {
  /// The index selected
  Btv<int?> selectIndex = Btv<int?>(null);

  /// Width for per column
  Map<String, Btv<double>?> columnsWidthMap = {};

  TextEditingController textEditingController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    /// Column per width
    double kColumnSeqWidth = 38;
    double kColumnMinWidth = 80;
    double kColumnDividerWidth = 1;

    /// Get column width
    double everyColumnWidth(String name) {
      return (columnsWidthMap[name] ??= Btv<double>(kColumnMinWidth)).value;
    }

    double getHeaderTotalWidth() {
      double width = 0;
      for (String name in widget.columnNames) {
        width += everyColumnWidth(name);
      }
      double result = width + (widget.columnNames.length - 1) * kColumnDividerWidth;
      if (widget.isShowSeq) {
        result = result + kColumnSeqWidth + kColumnDividerWidth;
      }
      return result;
    }

    /// if width is enough
    double contextWidth = MediaQuery.of(context).size.width;
    if (contextWidth > getHeaderTotalWidth()) {
      kColumnMinWidth =
          (contextWidth - (widget.columnNames.length - 1) * kColumnDividerWidth) / widget.columnNames.length;
      for (String name in widget.columnNames) {
        if (everyColumnWidth(name) < kColumnMinWidth) {
          columnsWidthMap[name]?.value = kColumnMinWidth;
        }
      }
    }

    /// Build a title
    Widget titleWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.tableName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            shadows: <Shadow>[
              Shadow(blurRadius: 8.0, offset: Offset(2.0, 8.0), color: Color.fromARGB(255, 0, 0, 0)),
              Shadow(blurRadius: 8.0, offset: Offset(8.0, 2.0), color: Color.fromARGB(125, 0, 0, 255)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text('${widget.rowsCount}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300, color: Colors.grey)),
      ],
    );

    /// Drag state
    double dragStartX = 0;
    double dragStartW = 0;

    Widget oneTableWidget = Btw(
      builder: (context) {
        Widget getOneHeaderElement({required String name, required double width}) {
          return Container(
            width: width,
            padding: const EdgeInsets.all(8),
            alignment: Alignment.center,
            child: Text(name, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
          );
        }

        Widget getOneRowElement({required String name, required String value, required double width}) {
          return Container(
            height: 25,
            width: width,
            alignment: Alignment.center,
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          );
        }

        /// Build a header
        List<Widget> headerSubViews = [];
        for (String name in widget.columnNames) {
          Widget w = Stack(
            children: [
              getOneHeaderElement(name: name, width: everyColumnWidth(name)),
              // draggable, for expanding the width of column
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  child: const ColoredBox(color: Colors.white, child: SizedBox(width: 30, height: 1)),
                  onHorizontalDragDown: (DragDownDetails details) {
                    dragStartW = everyColumnWidth(name);
                    dragStartX = details.localPosition.dx;
                  },
                  onHorizontalDragUpdate: (DragUpdateDetails details) {
                    columnsWidthMap[name]?.value = dragStartW + (details.localPosition.dx - dragStartX);
                  },
                ),
              ),
            ],
          );
          headerSubViews.add(w);
        }
        if (widget.isShowSeq) {
          headerSubViews.insert(0, getOneHeaderElement(name: 'Seq', width: kColumnSeqWidth));
        }
        Widget divider = Container(width: kColumnDividerWidth, height: 20, color: Colors.grey.withAlpha(64));
        headerSubViews.joinIn(divider);
        Widget headerWidget = Row(children: headerSubViews);

        /// Build a list view
        Widget listWidget = Scrollbar(
          controller: widget.scrollController,
          child: ListView.builder(
            controller: widget.scrollController,
            itemCount: widget.rowsCount,
            itemBuilder: (BuildContext context, int index) {
              Map<String, Object?> map = widget.rowsResults[index];
              List<String> keys = map.keys.toList();
              List<Widget> rowChildren = keys
                  .map(
                    (name) => getOneRowElement(
                        name: name, value: map[name]?.toString() ?? 'NULL', width: everyColumnWidth(name)),
                  )
                  .toList();
              return Listener(
                onPointerDown: (e) => selectIndex.value = index,
                child: Btw(
                  builder: (context) => GestureDetector(
                    onDoubleTap: () {
                      textEditingController.text = json.encode(map);
                      DialogWrapper.showCenter(WidgetUtil.newEditBox(controller: textEditingController));
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: selectIndex.value == index ? Colors.grey.withAlpha(128) : Colors.white,
                        border: Border(bottom: BorderSide(color: Colors.grey.withAlpha(32), width: 1)),
                      ),
                      child: Row(children: [
                        if (widget.isShowSeq) getOneRowElement(name: '', value: '$index', width: kColumnSeqWidth),
                        ...rowChildren,
                      ]),
                    ),
                  ),
                ),
              );
            },
          ),
        );

        return Container(
          height: widget.height,
          padding: const EdgeInsets.only(
            left: 8,
            right: 8,
            top: 8,
            bottom: 25,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.orange.withAlpha(64)),
              boxShadow: const [BoxShadow(color: Colors.grey, blurRadius: 20.0)],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: getHeaderTotalWidth(),
                child: Column(children: [headerWidget, Expanded(child: listWidget)]),
              ),
            ),
          ),
        );
      },
    );

    return Column(
      children: [
        titleWidget,
        oneTableWidget,
      ],
    );
  }
}
