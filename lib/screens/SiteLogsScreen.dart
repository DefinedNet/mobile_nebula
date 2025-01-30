import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:mobile_nebula/components/SimplePage.dart';
import 'package:mobile_nebula/models/Site.dart';
import 'package:mobile_nebula/services/logs.dart';
import 'package:mobile_nebula/services/result.dart';
import 'package:mobile_nebula/services/settings.dart';
import 'package:mobile_nebula/services/share.dart';
import 'package:mobile_nebula/services/utils.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../components/SiteTitle.dart';

class SiteLogsScreen extends StatefulWidget {
  const SiteLogsScreen({Key? key, required this.site}) : super(key: key);

  final Site site;

  @override
  _SiteLogsScreenState createState() => _SiteLogsScreenState();
}

class _SiteLogsScreenState extends State<SiteLogsScreen> {
  final ScrollController controller = ScrollController();
  final RefreshController refreshController = RefreshController(initialRefresh: false);
  final LogsNotifier logsNotifier = LogsNotifier();

  var settings = Settings();
  @override
  void initState() {
    logsNotifier.loadLogs(logFile: widget.site.logFile);
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = SiteTitle(site: widget.site);

    return SimplePage(
      title: title,
      trailingActions: [Padding(padding: const EdgeInsets.only(right: 8), child: _buildTextWrapToggle())],
      scrollable: SimpleScrollable.both,
      scrollController: controller,
      onRefresh: () async {
        await logsNotifier.loadLogs(logFile: widget.site.logFile);
        refreshController.refreshCompleted();
      },
      onLoading: () async {
        await logsNotifier.loadLogs(logFile: widget.site.logFile);
        refreshController.loadComplete();
      },
      refreshController: refreshController,
      child: Container(
          padding: EdgeInsets.all(5),
          constraints: logBoxConstraints(context),
          child: ListenableBuilder(
            listenable: logsNotifier,
            builder: (context, child) => SelectableText(
                switch (logsNotifier.logsResult) {
                  Ok<String>(:var value) => value.trim(),
                  Error<String>(:var error) => error is LogsNotFoundException
                      ? "No logs file found."
                      : Utils.popError(context, "Error while reading logs.", error.toString()),
                  null => "",
                },
                style: TextStyle(fontFamily: 'RobotoMono', fontSize: 14)),
          )),
      bottomBar: _buildBottomBar(),
    );
  }

  Widget _buildTextWrapToggle() {
    return Platform.isIOS
        ? Tooltip(
            message: "Turn ${settings.logWrap ? "off" : "on"} text wrapping",
            child: CupertinoButton.tinted(
              // Use the default tint when enabled, match the background when not.
              color: settings.logWrap ? null : CupertinoColors.systemBackground,
              sizeStyle: CupertinoButtonSize.small,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              child: const Icon(Icons.wrap_text),
              onPressed: () => {
                setState(() {
                  settings.logWrap = !settings.logWrap;
                })
              },
            ),
          )
        : IconButton.filledTonal(
            isSelected: settings.logWrap,
            tooltip: "Turn ${settings.logWrap ? "off" : "on"} text wrapping",
            // The variants of wrap_text seem to be the same, but this seems most correct.
            selectedIcon: const Icon(Icons.wrap_text_outlined),
            icon: const Icon(Icons.wrap_text),
            onPressed: () => {
              setState(() {
                settings.logWrap = !settings.logWrap;
              })
            },
          );
  }

  Widget _buildBottomBar() {
    var borderSide = BorderSide(
      color: CupertinoColors.separator,
      style: BorderStyle.solid,
      width: 0.0,
    );

    var padding = Platform.isAndroid ? EdgeInsets.fromLTRB(0, 20, 0, 30) : EdgeInsets.all(10);

    return PlatformWidgetBuilder(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          spacing: 8,
          children: <Widget>[
            Tooltip(
              message: "Share logs",
              child: PlatformIconButton(
                icon: Icon(context.platformIcons.share),
                onPressed: () {
                  Share.shareFile(context,
                      title: '${widget.site.name} logs',
                      filePath: widget.site.logFile,
                      filename: '${widget.site.name}.log');
                },
              ),
            ),
            Tooltip(
              message: 'Go to latest',
              child: PlatformIconButton(
                icon: Icon(context.platformIcons.downArrow),
                onPressed: () async {
                  controller.animateTo(controller.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 500), curve: Curves.linearToEaseOut);
                },
              ),
            ),
          ],
        ),
        cupertino: (context, child, platform) => Container(
            decoration: BoxDecoration(
              border: Border(top: borderSide),
            ),
            padding: padding,
            child: child),
        material: (context, child, platform) => BottomAppBar(child: child));
  }

  logBoxConstraints(BuildContext context) {
    if (settings.logWrap) {
      return BoxConstraints(maxWidth: MediaQuery.of(context).size.width);
    } else {
      return BoxConstraints(minWidth: MediaQuery.of(context).size.width);
    }
  }
}
