import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

/// Tar bar with background gradual color animation
class BoxTabBar extends StatelessWidget {
  BoxTabBar({
    Key? key,
    required this.titles,
    this.tabController,
    // title label color
    this.labelColor = const Color(0xFF006BE1),
    this.unselectedLabelColor = const Color(0xFF31456A),
    // title label style
    this.labelStyle, // = const TextStyle(color: Color(0xFF006BE1), fontSize: 12, fontWeight: FontWeight.w500),
    this.unselectedLabelStyle, // = const TextStyle(color: Color(0xFF31456A), fontSize: 12, fontWeight: FontWeight.w400),
    // tab background color
    this.boxSelectedColor,
    this.boxUnselectedColor,
  }) : super(key: key);

  final List<String> titles;
  final TabController? tabController;

  // title label color
  final Color? labelColor;
  final Color? unselectedLabelColor;

  // title label style
  final TextStyle? labelStyle;
  final TextStyle? unselectedLabelStyle;

  // tab background color
  final Color? boxSelectedColor;
  final Color? boxUnselectedColor;

  @override
  Widget build(BuildContext context) {
    return TabBar(
      isScrollable: true,
      controller: tabController,
      indicator: const BoxDecoration(),
      indicatorSize: TabBarIndicatorSize.label,
      labelColor: labelColor,
      unselectedLabelColor: unselectedLabelColor,
      labelStyle: labelStyle,
      unselectedLabelStyle: unselectedLabelStyle,
      labelPadding: EdgeInsets.zero,
      tabs: createTabs(titles),
      onTap: (i) {
        // nothing now ...
      },
    );
  }

  /// Create Tabs
  List<Widget> createTabs(List<String> list) {
    /// If selected
    bool isSelectedTab(int i) => tabController?.index == i;
    String getTitle(int i) => (i < 0 || i >= list.length ? null : list.elementAt(i)) ?? '';
    EdgeInsets getMargin(i) => i == list.length - 1 ? EdgeInsets.zero : EdgeInsets.only(right: 8);

    Color _boxSelectedColor = boxSelectedColor ?? Color(0x1A006BE1).withAlpha(32);
    Color _boxUnselectedColor = boxUnselectedColor ?? Color(0x0831456A).withAlpha(16);
    List<Widget> children = <Widget>[
      for (int i = 0; i < list.length; i++)
        TabBackgroundAnimatedBar.transitionBox(
          getTitle(i),
          isSelectedTab(i),
          getMargin(i),
          _boxSelectedColor,
          _boxUnselectedColor,
          0,
        )
    ];
    if (tabController == null) {
      return children;
    }
    TabController _controller = tabController!;
    int currentIndex = _controller.index;
    int previousIndex = _controller.previousIndex;
    if (_controller.indexIsChanging) {
      /// The user tapped on a tab, the tab controller's animation is running.
      assert(currentIndex != previousIndex);
      return children;
    }

    /// The user is dragging the TabBarView's PageView left or right.
    Widget getAnimatedTab(int index, Animation<double> animation) {
      return TabBackgroundAnimatedBar(
        title: getTitle(index),
        selected: isSelectedTab(index),
        margin: getMargin(index),
        selectedColor: _boxSelectedColor,
        unselectedColor: _boxUnselectedColor,
        animation: animation,
      );
    }

    children[currentIndex] = getAnimatedTab(currentIndex, TabBarDragAnimation(_controller, currentIndex));
    if (currentIndex > 0) {
      final int index = currentIndex - 1;
      children[index] = getAnimatedTab(index, ReverseAnimation(TabBarDragAnimation(_controller, index)));
    }
    if (currentIndex < _controller.length - 1) {
      final int index = currentIndex + 1;
      children[index] = getAnimatedTab(index, ReverseAnimation(TabBarDragAnimation(_controller, index)));
    }
    return children;
  }
}

class TabBackgroundAnimatedBar extends AnimatedWidget {
  const TabBackgroundAnimatedBar({
    Key? key,
    required this.title,
    required this.selected,
    required this.margin,
    required this.animation,
    required this.selectedColor,
    required this.unselectedColor,
  }) : super(listenable: animation);

  final String title;
  final bool selected;
  final EdgeInsets margin;
  final Animation<double> animation;
  final Color selectedColor;
  final Color unselectedColor;

  @override
  Widget build(BuildContext context) => transitionBox(title, selected, margin, selectedColor, unselectedColor, animation.value);

  static Widget transitionBox(
    String title,
    bool selected,
    EdgeInsets margin,
    Color selectedColor,
    Color unselectedColor,
    double ratio,
  ) {
    return Container(
      margin: margin,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(4)),
        color: Color.lerp(selected ? selectedColor : unselectedColor, selected ? unselectedColor : selectedColor, ratio),
      ),
      child: Text(title),
    );
  }
}

class TabBarDragAnimation extends Animation<double> with AnimationWithParentMixin<double> {
  TabBarDragAnimation(this.controller, this.index);

  final TabController controller;
  final int index;

  @override
  Animation<double> get parent => controller.animation!;

  @override
  void removeStatusListener(AnimationStatusListener listener) {
    if (controller.animation != null) {
      super.removeStatusListener(listener);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    if (controller.animation != null) {
      super.removeListener(listener);
    }
  }

  @override
  double get value {
    // assert(!controller.indexIsChanging);
    final double controllerMaxValue = (controller.length - 1).toDouble();
    final double controllerValue = controller.animation!.value.clamp(0.0, controllerMaxValue);
    return (controllerValue - index.toDouble()).abs().clamp(0.0, 1.0);
  }
}
