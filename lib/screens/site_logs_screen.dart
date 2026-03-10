import 'package:flutter/material.dart';
import 'package:mobile_nebula/components/simple_page.dart';
import 'package:mobile_nebula/models/site.dart';
import 'package:mobile_nebula/services/logs.dart';
import 'package:mobile_nebula/services/result.dart';
import 'package:mobile_nebula/services/settings.dart';
import 'package:mobile_nebula/services/share.dart';
import 'package:mobile_nebula/services/utils.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../components/site_title.dart';

class SiteLogsScreen extends StatefulWidget {
  const SiteLogsScreen({super.key, required this.site});

  final Site site;

  @override
  SiteLogsScreenState createState() => SiteLogsScreenState();
}

class SiteLogsScreenState extends State<SiteLogsScreen> {
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
      bottomBar: _buildBottomBar(),
      child: Container(
        padding: EdgeInsets.all(5),
        constraints: logBoxConstraints(context),
        child: ListenableBuilder(
          listenable: logsNotifier,
          builder: (context, child) {
            var text = "";
            switch (logsNotifier.logsResult) {
              case Ok<String>(:var value):
                text = value.trim();
                break;
              case Error<String>(:var error):
                if (error is LogsNotFoundException) {
                  text = error.error();
                } else {
                  text = "";
                  Utils.popError("Error while reading logs.", error.toString());
                }
                break;
              default:
                text = "";
                break;
            }

            return SelectableText(text, style: TextStyle(fontFamily: 'RobotoMono', fontSize: 14));
          },
        ),
      ),
    );
  }

  Widget _buildTextWrapToggle() {
    return IconButton.filledTonal(
      isSelected: settings.logWrap,
      tooltip: "Turn ${settings.logWrap ? "off" : "on"} text wrapping",
      selectedIcon: const Icon(Icons.wrap_text_outlined),
      icon: const Icon(Icons.wrap_text),
      onPressed: () => {
        setState(() {
          settings.logWrap = !settings.logWrap;
        }),
      },
    );
  }

  Widget _buildBottomBar() {
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        spacing: 8,
        children: <Widget>[
          Tooltip(
            message: "Share logs",
            child: IconButton(
              icon: Icon(Icons.share),
              onPressed: () {
                Share.shareFile(
                  context,
                  title: '${widget.site.name} logs',
                  filePath: widget.site.logFile,
                  filename: '${widget.site.name}.log',
                );
              },
            ),
          ),
          Tooltip(
            message: 'Go to latest',
            child: IconButton(
              icon: Icon(Icons.arrow_downward),
              onPressed: () async {
                controller.animateTo(
                  controller.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.linearToEaseOut,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  BoxConstraints logBoxConstraints(BuildContext context) {
    if (settings.logWrap) {
      return BoxConstraints(maxWidth: MediaQuery.of(context).size.width);
    } else {
      return BoxConstraints(minWidth: MediaQuery.of(context).size.width);
    }
  }
}
