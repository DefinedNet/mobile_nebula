import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:mobile_nebula/components/SimplePage.dart';
import 'package:mobile_nebula/components/SpecialSelectableText.dart';
import 'package:mobile_nebula/models/Site.dart';
import 'package:mobile_nebula/services/settings.dart';
import 'package:mobile_nebula/services/share.dart';
import 'package:mobile_nebula/services/utils.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class SiteLogsScreen extends StatefulWidget {
  const SiteLogsScreen({Key key, this.site}) : super(key: key);

  final Site site;

  @override
  _SiteLogsScreenState createState() => _SiteLogsScreenState();
}

class _SiteLogsScreenState extends State<SiteLogsScreen> {
  String logs = '';
  ScrollController controller = ScrollController();
  RefreshController refreshController = RefreshController(initialRefresh: false);

  var settings = Settings();
  @override
  void initState() {
    loadLogs();
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      title: widget.site.name,
      scrollable: SimpleScrollable.both,
      scrollController: controller,
      onRefresh: () async {
        await loadLogs();
        refreshController.refreshCompleted();
      },
      onLoading: () async {
        await loadLogs();
        refreshController.loadComplete();
      },
      refreshController: refreshController,
      child: Container(padding: EdgeInsets.all(5), constraints: logBoxConstraints(context), child: SpecialSelectableText(logs.trim(), style: TextStyle(fontFamily: 'RobotoMono', fontSize: 14))),
      bottomBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    var borderSide = BorderSide(
      color: CupertinoColors.separator,
      style: BorderStyle.solid,
      width: 0.0,
    );

    var padding = Platform.isAndroid ? EdgeInsets.fromLTRB(0, 20, 0, 30) : EdgeInsets.all(10);

    return Container(
        decoration: BoxDecoration(
          border: Border(top: borderSide),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
          Expanded(
              child: PlatformIconButton(
            padding: padding,
            icon: Icon(context.platformIcons.share, size: 30),
            onPressed: () {
              Share.shareFile(title: '${widget.site.name} logs', filePath: widget.site.logFile, filename: '${widget.site.name}.log');
            },
          )),
          Expanded(
              child: PlatformIconButton(
            padding: padding,
            icon: Icon(context.platformIcons.delete, size: Platform.isIOS ? 38 : 30),
            onPressed: () {
              Utils.confirmDelete(context, 'Are you sure you want to clear all logs?', () => deleteLogs());
            },
          )),
          Expanded(
              child: PlatformIconButton(
            padding: padding,
            icon: Icon(context.platformIcons.downArrow, size: 30),
            onPressed: () async {
              controller.animateTo(controller.position.maxScrollExtent, duration: const Duration(milliseconds: 500), curve: Curves.linearToEaseOut);
            },
          )),
        ]));
  }

  loadLogs() async {
    var file = File(widget.site.logFile);
    try {
      final v = await file.readAsString();

      setState(() {
        logs = v;
      });
    } catch (err) {
      Utils.popError(context, 'Error while reading logs', err.toString());
    }
  }

  deleteLogs() async {
    var file = File(widget.site.logFile);
    await file.writeAsBytes([]);
    await loadLogs();
  }

  logBoxConstraints(BuildContext context) {
    if (settings.logWrap) {
      return BoxConstraints(maxWidth: MediaQuery.of(context).size.width);
    } else {
      return BoxConstraints(minWidth: MediaQuery.of(context).size.width);
    }
  }
}
