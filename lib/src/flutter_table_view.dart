// ignore_for_file: public_member_api_docs, sort_constructors_first
part of flutter_table_view;

typedef TableViewItemBuilder = Widget Function(
    BuildContext context, IndexPath indexPath);

typedef TableViewFooterBuilder = Widget? Function(
  BuildContext context,
  int sectionIndex,
);

/// isHover: 表示当前Header是否悬停， FlutterTableViewStyle.grouped 且 悬停时为true
typedef TableViewHeaderBuilder = Widget? Function(
  BuildContext context,
  int sectionIndex,
  bool isHover,
);

typedef TableReusableViewSelectedHandler = void Function(
    BuildContext context, int sectionIndex);

typedef TableViewItemSelectedHandler = void Function(
    BuildContext context, IndexPath indexPath);

enum FlutterTableViewStyle {
  /// header 不会悬停
  plain,

  /// header 可以悬停
  grouped,
}

class FlutterTableView extends StatefulWidget {
  /// 返回section个数
  final int Function() sectionCount;

  /// 返回每个section中的cell个数
  final int Function(int) rowCount;

  /// 提供刷新、滚动
  final FlutterTableViewController controller;

  /// 类比ios UITableView
  /// plain : header不悬停
  /// grouped: header悬停
  final FlutterTableViewStyle style;

  /// cell构造器
  final TableViewItemBuilder itemBuilder;

  /// 提供header
  final TableViewHeaderBuilder? headerBuilder;

  /// 提供footer
  final TableViewFooterBuilder? footerBuilder;

  /// 点击cell
  final TableViewItemSelectedHandler? onSelectedItem;

  /// 点击头
  final TableReusableViewSelectedHandler? onSelectedHeader;

  /// 点击footer
  final TableReusableViewSelectedHandler? onSelectedFooter;

  /// 首次自动加载
  final bool autoLoad;

  /// 点击头

  /// header偏移高度
  final double headerOffset;

  /// 最后追加多少个item， 有数据的时候才会追加
  final int additionalNumber;

  /// 追加的builder
  final Widget Function(BuildContext context, int index)? additionalBuilder;

  /// ScrollablePositionedList 参数
  final bool shrinkWrap;
  final Axis scrollDirection;
  final bool reverse;
  final ScrollPhysics? physics;
  final EdgeInsets? padding;
  final double? minCacheExtent;
  final int? semanticChildCount;
  final bool addSemanticIndexes;
  final bool addAutomaticKeepAlives;
  final bool addRepaintBoundaries;

  const FlutterTableView({
    Key? key,
    required this.sectionCount,
    required this.rowCount,
    required this.controller,
    required this.itemBuilder,
    this.headerOffset = 0,
    this.style = FlutterTableViewStyle.plain,
    this.headerBuilder,
    this.footerBuilder,
    this.shrinkWrap = false,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.autoLoad = false,
    this.physics,
    this.semanticChildCount,
    this.padding,
    this.minCacheExtent,
    this.addSemanticIndexes = true,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.additionalNumber = 0,
    this.additionalBuilder,
    this.onSelectedItem,
    this.onSelectedHeader,
    this.onSelectedFooter,
  })  : assert(additionalNumber >= 0),
        super(key: key);

  @override
  State<FlutterTableView> createState() => _FlutterTableViewState();
}

class _FlutterTableViewState extends State<FlutterTableView> {
  final ItemScrollController itemScrollController = ItemScrollController();

  final ItemPositionsListener itemPositionsListener =
      ItemPositionsListener.create();

  late final _TableViewCountManager countManger;

  late final _TableViewDataSource dataSource;

  final _HeaderKey _headerKey = _HeaderKey();

  final UniqueKey _tableViewKey = UniqueKey();

  bool hadScrollToInitialIndex = false;

  @override
  void initState() {
    super.initState();
    dataSource = _TableViewDataSource();

    countManger = _TableViewCountManager(dataSource: dataSource);
    configDataSource();

    if (widget.autoLoad) {
      countManger.reloadSection();
    }
  }

  void configDataSource() {
    dataSource.sectionCount = widget.sectionCount;
    dataSource.rowCount = widget.rowCount;
    widget.controller
      .._countManger = countManger
      .._itemPositionsListener = itemPositionsListener
      .._itemScrollController = itemScrollController;
  }

  @override
  void didUpdateWidget(covariant FlutterTableView oldWidget) {
    configDataSource();
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    countManger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ValueListenableBuilder<int>(
          valueListenable: countManger,
          key: _tableViewKey,
          builder: (context, count, child) {
            final itemCount =
                count > 0 ? (count + widget.additionalNumber) : count;
            return ScrollablePositionedList.builder(
              itemCount: itemCount,
              physics: widget.physics,
              itemScrollController: itemScrollController,
              shrinkWrap: widget.shrinkWrap,
              itemPositionsListener: itemPositionsListener,
              scrollDirection: widget.scrollDirection,
              reverse: widget.reverse,
              semanticChildCount: widget.semanticChildCount,
              padding: widget.padding,
              addSemanticIndexes: widget.addSemanticIndexes,
              addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
              minCacheExtent: widget.minCacheExtent,
              itemBuilder: (context, index) {
                if (index >= count) {
                  final additionalIndex = index - count;

                  final indexPath = countManger
                      .indexPathWithIndex(index - additionalIndex - 1);
                  final sectionCount = dataSource.sectionCount();

                  /// 前一个section是最后一个section才调用刷新
                  if (indexPath != null &&
                      indexPath.section == (sectionCount - 1)) {
                    if (widget.additionalBuilder != null &&
                        additionalIndex >= 0 &&
                        additionalIndex < widget.additionalNumber) {
                      return widget.additionalBuilder
                              ?.call(context, additionalIndex) ??
                          Container();
                    }
                  }
                  return Container();
                } else {
                  final indexPath = countManger.indexPathWithIndex(index);
                  if (indexPath == null) {
                    return Container();
                  } else {
                    final sectionCount = dataSource.sectionCount();
                    final rowCount = dataSource.rowCount(indexPath.section);
                    if (indexPath.section >= 0 &&
                        indexPath.section < sectionCount &&
                        indexPath.row >= 0 &&
                        indexPath.row < rowCount) {
                      return buildItem(context, indexPath, rowCount);
                    }
                    return const SizedBox.shrink();
                  }
                }
              },
            );
          },
        ),
        if (widget.style == FlutterTableViewStyle.grouped)
          _buildHeader(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    if (widget.headerBuilder == null) return Container();
    return ValueListenableBuilder<Iterable<ItemPosition>>(
      valueListenable: itemPositionsListener.itemPositions,
      builder: (ctx, positions, _) {
        if (positions.isEmpty) return Container();
        final paintBounds = context.findRenderObject()?.paintBounds;
        bool isVertical = widget.scrollDirection == Axis.vertical;

        final mainAxisLength =
            (isVertical ? paintBounds?.height : paintBounds?.width) ?? 0;
        if (mainAxisLength == 0) return Container();

        final minTrailingEdge = widget.headerOffset / mainAxisLength;

        /// 不确定是否数组第一个就是可见区域内的第一个，通过下方计算找到
        ItemPosition itemPosition = positions
            .where((ItemPosition position) =>
                position.itemTrailingEdge > minTrailingEdge)
            .reduce((ItemPosition min, ItemPosition position) =>
                position.itemTrailingEdge < min.itemTrailingEdge
                    ? position
                    : min);

        /// itemLeadingEdge 为负数，则是第一个  且有区域在可见区域之外
        if (itemPosition.itemLeadingEdge > minTrailingEdge) return Container();

        final index = itemPosition.index;
        final indexPath = countManger.indexPathWithIndex(index);
        if (indexPath == null) return Container();

        final sectionCount = dataSource.sectionCount();

        /// 对应section没有cell
        if (indexPath.section >= sectionCount ||
            dataSource.rowCount(indexPath.section) <= 0) return Container();

        double mainAxisSpace = 0;

        double opacity = 1;

        /// 如果当前row是最后一个 则根据显示在可见区域中的高度 调整偏移
        if (indexPath.row == dataSource.rowCount(indexPath.section) - 1) {
          ///cell的可见高度
          final mainAxisTemp = itemPosition.itemTrailingEdge * mainAxisLength;

          final headerRender =
              _headerKey.currentContext?.findRenderObject() as RenderBox?;
          if (headerRender != null) {
            var headerMainAxisLength =
                isVertical ? headerRender.size.height : headerRender.size.width;

            headerMainAxisLength += widget.headerOffset;

            if (headerMainAxisLength == 0 &&
                _headerKey.section != indexPath.section) {
              /// 如果切换时，上一个header的高度为0, 会闪烁一下
              opacity = 0;
            } else {
              mainAxisSpace = math.min(0, mainAxisTemp - headerMainAxisLength);
            }
          }
        }

        mainAxisSpace += widget.headerOffset;
        _headerKey.section = indexPath.section;

        var headerWideget = widget.headerBuilder?.call(
          context,
          indexPath.section,
          true,
        );
        if (headerWideget == null) return Container();
        if (widget.onSelectedHeader != null) {
          headerWideget = GestureDetector(
            behavior: HitTestBehavior.translucent,
            child: headerWideget,
            onTap: () {
              widget.onSelectedHeader?.call(context, indexPath.section);
            },
          );
        }
        if (isVertical) {
          if (widget.reverse) {
            return Positioned(
              key: _headerKey,
              left: 0,
              bottom: mainAxisSpace,
              right: 0,
              child: Opacity(
                opacity: opacity,
                child: headerWideget,
              ),
            );
          } else {
            return Positioned(
              key: _headerKey,
              left: 0,
              top: mainAxisSpace,
              right: 0,
              child: Opacity(
                opacity: opacity,
                child: headerWideget,
              ),
            );
          }
        } else {
          if (widget.reverse) {
            return Positioned(
              key: _headerKey,
              right: mainAxisSpace,
              top: 0,
              bottom: 0,
              child: Opacity(
                opacity: opacity,
                child: headerWideget,
              ),
            );
          } else {
            return Positioned(
              key: _headerKey,
              left: mainAxisSpace,
              top: 0,
              bottom: 0,
              child: Opacity(
                opacity: opacity,
                child: headerWideget,
              ),
            );
          }
        }
      },
    );
  }

  Widget buildItem(BuildContext context, IndexPath indexPath, int rowCount) {
    var itemWidegt = widget.itemBuilder(context, indexPath);
    if (widget.onSelectedItem != null) {
      itemWidegt = GestureDetector(
        behavior: HitTestBehavior.translucent,
        child: itemWidegt,
        onTap: () {
          widget.onSelectedItem?.call(context, indexPath);
        },
      );
    }

    Widget? header;
    Widget? footer;
    if (indexPath.row == 0) {
      header = widget.headerBuilder?.call(
        context,
        indexPath.section,
        false,
      );
      if (widget.onSelectedHeader != null) {
        header = GestureDetector(
          behavior: HitTestBehavior.translucent,
          child: header,
          onTap: () {
            widget.onSelectedHeader?.call(context, indexPath.section);
          },
        );
      }
    }
    if (indexPath.row == rowCount - 1) {
      footer = widget.footerBuilder?.call(
        context,
        indexPath.section,
      );
      if (widget.onSelectedFooter != null) {
        footer = GestureDetector(
          behavior: HitTestBehavior.translucent,
          child: footer,
          onTap: () {
            widget.onSelectedFooter?.call(context, indexPath.section);
          },
        );
      }
    }

    if (header != null || footer != null) {
      List<Widget> children = widget.reverse
          ? [
              if (footer != null) footer,
              itemWidegt,
              if (header != null) header,
            ]
          : [
              if (header != null) header,
              itemWidegt,
              if (footer != null) footer,
            ];
      if (widget.scrollDirection == Axis.vertical) {
        itemWidegt = Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        );
      } else {
        itemWidegt = Row(
          mainAxisSize: MainAxisSize.min,
          children: children,
        );
      }
    }
    return itemWidegt;
  }
}

// ignore: must_be_immutable
class _HeaderKey<T extends State<StatefulWidget>> extends LabeledGlobalKey<T> {
  int? section;

  _HeaderKey() : super(null);
}
