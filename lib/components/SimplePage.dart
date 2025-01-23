import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:mobile_nebula/services/utils.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

enum SimpleScrollable {
  none,
  vertical,
  horizontal,
  both,
}

class SimplePage extends StatelessWidget {
  const SimplePage(
      {Key? key,
      required this.title,
      required this.child,
      this.leadingAction,
      this.trailingActions = const [],
      this.scrollable = SimpleScrollable.vertical,
      this.scrollbar = true,
      this.scrollController,
      this.bottomBar,
      this.onRefresh,
      this.onLoading,
      this.alignment,
      this.refreshController})
      : super(key: key);

  final Widget title;
  final Widget child;
  final SimpleScrollable scrollable;
  final ScrollController? scrollController;
  final AlignmentGeometry? alignment;

  /// Set this to true to force draw a scrollbar without a scroll view, this is helpful for pages with Reorder-able listviews
  /// This is set to true if you have any scrollable other than none
  final bool scrollbar;
  final Widget? bottomBar;

  /// If no leading action is provided then a default "Back" widget than pops the page will be provided
  final Widget? leadingAction;
  final List<Widget> trailingActions;

  final VoidCallback? onRefresh;
  final VoidCallback? onLoading;
  final RefreshController? refreshController;

  @override
  Widget build(BuildContext context) {
    Widget realChild = child;
    var addScrollbar = this.scrollbar;

    if (scrollable == SimpleScrollable.vertical || scrollable == SimpleScrollable.both) {
      realChild = SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: realChild,
          controller: refreshController == null ? scrollController : null);
      addScrollbar = true;
    }

    if (scrollable == SimpleScrollable.horizontal || scrollable == SimpleScrollable.both) {
      realChild = SingleChildScrollView(scrollDirection: Axis.horizontal, child: realChild);
      addScrollbar = true;
    }

    if (refreshController != null) {
      realChild = RefreshConfiguration(
          headerTriggerDistance: 100,
          footerTriggerDistance: -100,
          maxUnderScrollExtent: 100,
          child: SmartRefresher(
            scrollController: scrollController,
            onRefresh: onRefresh,
            onLoading: onLoading,
            controller: refreshController!,
            child: realChild,
            enablePullUp: onLoading != null,
            enablePullDown: onRefresh != null,
            footer: ClassicFooter(loadStyle: LoadStyle.ShowWhenLoading),
          ));
      addScrollbar = true;
    }

    if (addScrollbar) {
      realChild = Scrollbar(child: realChild);
    }

    if (alignment != null) {
      realChild = Align(alignment: this.alignment!, child: realChild);
    }

    if (bottomBar != null) {
      realChild = Column(children: [
        Expanded(child: realChild),
        bottomBar!,
      ]);
    }

    return PlatformScaffold(
        backgroundColor: cupertino.CupertinoColors.systemGroupedBackground.resolveFrom(context),
        appBar: PlatformAppBar(
          title: title,
          leading: leadingAction,
          trailingActions: trailingActions,
          cupertino: (_, __) => CupertinoNavigationBarData(
            transitionBetweenRoutes: false,
          ),
        ),
        body: SafeArea(child: realChild));
  }
}
