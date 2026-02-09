import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:mobile_nebula/components/simple_page.dart';
import 'package:mobile_nebula/components/site_item.dart';
import 'package:mobile_nebula/models/site.dart';
import 'package:mobile_nebula/screens/settings_screen.dart';
import 'package:mobile_nebula/screens/siteConfig/site_config_screen.dart';
import 'package:mobile_nebula/screens/site_detail_screen.dart';
import 'package:mobile_nebula/services/utils.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class MainScreen extends StatefulWidget {
  const MainScreen(this.dnEnrollStream, {super.key});

  final StreamController dnEnrollStream;

  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  List<Site> sites = [];
  // A set of widgets to display in a column that represents an error blocking us from moving forward entirely
  List<Widget>? error;

  bool supportsQRScanning = false;

  static const platform = MethodChannel('net.defined.mobileNebula/NebulaVpnService');
  RefreshController refreshController = RefreshController();
  ScrollController scrollController = ScrollController();

  @override
  void initState() {
    _loadSites();

    widget.dnEnrollStream.stream.listen((_) {
      _loadSites();
    });

    platform.setMethodCallHandler(handleMethodCall);

    super.initState();
  }

  @override
  void dispose() {
    scrollController.dispose();
    refreshController.dispose();
    super.dispose();
  }

  Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case "refreshSites":
        _loadSites();
        break;
      default:
        print("ERR: Unexpected method call ${call.method}");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine whether the device supports QR scanning. For example, some
    // Chromebooks do not have camera support.
    if (Platform.isAndroid) {
      platform
          .invokeMethod("android.deviceHasCamera")
          .then((hasCamera) => setState(() => supportsQRScanning = hasCamera));
    } else {
      supportsQRScanning = true;
    }

    return SimplePage(
      title: Text('Nebula'),
      scrollable: SimpleScrollable.vertical,
      leadingAction: PlatformIconButton(
        padding: EdgeInsets.zero,
        icon: Icon(Icons.add, size: 28.0),
        onPressed:
            () => Utils.openPage(context, (context) {
              return SiteConfigScreen(
                onSave: (_) {
                  _loadSites();
                },
                supportsQRScanning: supportsQRScanning,
              );
            }),
      ),
      refreshController: refreshController,
      onRefresh: () {
        _loadSites();
        refreshController.refreshCompleted();
      },
      trailingActions: <Widget>[
        PlatformIconButton(
          padding: EdgeInsets.zero,
          icon: Icon(Icons.adaptive.more, size: 28.0),
          onPressed: () => Utils.openPage(context, (_) => SettingsScreen(widget.dnEnrollStream, () => _loadSites())),
        ),
      ],
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 0, horizontal: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: error!,
          ),
        ),
      );
    }

    return _buildSites();
  }

  Widget _buildNoSites() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Center(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 8.0, 0, 8.0),
              child: Text('Welcome to Nebula!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            ),
            Text(
              'You don\'t have any site configurations installed yet. Hit the plus button above to get started.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSites() {
    if (sites.isEmpty) {
      return _buildNoSites();
    }

    List<Widget> items = [];
    for (var site in sites) {
      items.add(
        SiteItem(
          key: Key(site.id),
          site: site,
          onPressed: () {
            Utils.openPage(context, (context) {
              return SiteDetailScreen(
                site: site,
                onChanged: () => _loadSites(),
                supportsQRScanning: supportsQRScanning,
              );
            });
          },
        ),
      );
    }

    Widget child = ReorderableListView(
      shrinkWrap: true,
      scrollController: scrollController,
      padding: EdgeInsets.symmetric(vertical: 5),
      children: items,
      onReorder: (oldI, newI) async {
        if (oldI < newI) {
          // removing the item at oldIndex will shorten the list by 1.
          newI -= 1;
        }

        setState(() {
          final Site moved = sites.removeAt(oldI);
          sites.insert(newI, moved);
        });

        for (var i = 0; i < sites.length; i++) {
          if (sites[i].sortKey == i) {
            continue;
          }

          sites[i].sortKey = i;
          try {
            await sites[i].save();
          } catch (err) {
            //TODO: display error at the end
            print('ERR ${sites[i].name} - $err');
          }
        }

        _loadSites();
      },
    );

    if (Platform.isIOS) {
      child = CupertinoTheme(data: CupertinoTheme.of(context), child: child);
    }

    // The theme here is to remove the hardcoded canvas border reordering forces on us
    return Theme(data: Theme.of(context).copyWith(canvasColor: Colors.transparent), child: child);
  }

  _loadSites() async {
    //TODO: This can throw, we need to show an error dialog
    Map<String, dynamic> rawSites = jsonDecode(await platform.invokeMethod('listSites'));
    for (var site in sites) {
      site.dispose();
    }

    sites.clear();
    rawSites.forEach((id, rawSite) {
      try {
        var site = Site.fromJson(rawSite);

        site.onChange().listen(
          (_) {
            setState(() {});
          },
          onError: (err) {
            setState(() {});
            Utils.popError("${site.name} Error", err);
          },
        );

        sites.add(site);
      } catch (err) {
        //TODO: handle error
        print(err);
        print("site config: $rawSite");
        // Sometimes it is helpful to just nuke these is dev
        // platform.invokeMethod('deleteSite', id);
      }
    });

    if (Platform.isAndroid) {
      // Android suffers from a race to discover the active site and attach site specific event listeners
      platform.invokeMethod("android.registerActiveSite");
    }

    sites.sort((a, b) {
      if (a.sortKey == b.sortKey) {
        return a.name.compareTo(b.name);
      }

      return a.sortKey - b.sortKey;
    });

    setState(() {});
  }
}
