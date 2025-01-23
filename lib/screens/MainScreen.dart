import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:mobile_nebula/components/SimplePage.dart';
import 'package:mobile_nebula/components/SiteItem.dart';
import 'package:mobile_nebula/models/Certificate.dart';
import 'package:mobile_nebula/models/IPAndPort.dart';
import 'package:mobile_nebula/models/Site.dart';
import 'package:mobile_nebula/models/StaticHosts.dart';
import 'package:mobile_nebula/models/UnsafeRoute.dart';
import 'package:mobile_nebula/screens/SettingsScreen.dart';
import 'package:mobile_nebula/screens/SiteDetailScreen.dart';
import 'package:mobile_nebula/screens/siteConfig/SiteConfigScreen.dart';
import 'package:mobile_nebula/services/utils.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:uuid/uuid.dart';

/// Contains an expired CA and certificate
const badDebugSave = {
  'name': 'Bad Site',
  'cert': '''-----BEGIN NEBULA CERTIFICATE-----
CmIKBHRlc3QSCoKUoIUMgP7//w8ourrS+QUwjre3iAY6IDbmIX5cwd+UYVhLADLa
A5PwucZPVrNtP0P9NJE0boM2SiBSGzy8bcuFWWK5aVArJGA9VDtLg1HuujBu8lOp
VTgklxJAgbI1Xb1C9JC3a1Cnc6NPqWhnw+3VLoDXE9poBav09+zhw5DPDtgvQmxU
Sbw6cAF4gPS4e/tZ5Kjc8QEvjk3HDQ==
-----END NEBULA CERTIFICATE-----''',
  'key': '''-----BEGIN NEBULA X25519 PRIVATE KEY-----
rmXnR1yvDZi1VPVmnNVY8NMsQpEpbbYlq7rul+ByQvg=
-----END NEBULA X25519 PRIVATE KEY-----''',
  'ca': '''-----BEGIN NEBULA CERTIFICATE-----
CjkKB3Rlc3QgY2EopYyK9wUwpfOOhgY6IHj4yrtHbq+rt4hXTYGrxuQOS0412uKT
4wi5wL503+SAQAESQPhWXuVGjauHS1Qqd3aNA3DY+X8CnAweXNEoJKAN/kjH+BBv
mUOcsdFcCZiXrj7ryQIG1+WfqA46w71A/lV4nAc=
-----END NEBULA CERTIFICATE-----''',
};

/// Contains an expired CA and certificate
const goodDebugSave = {
  'name': 'Good Site',
  'cert': '''-----BEGIN NEBULA CERTIFICATE-----
CmcKCmRlYnVnIGhvc3QSCYKAhFCA/v//DyiX0ZaaBjDjjPf5ETogyYzKdlRh7pW6
yOd8+aMQAFPha2wuYixuq53ru9+qXC9KIJd3ow6qIiaHInT1dgJvy+122WK7g86+
Z8qYtTZnox1cEkBYpC0SySrCp6jd/zeAFEJM6naPYgc6rmy/H/qveyQ6WAtbgLpK
tM3EXbbOE9+fV/Ma6Oilf1SixO3ZBo30nRYL
-----END NEBULA CERTIFICATE-----''',
  'key': '''-----BEGIN NEBULA X25519 PRIVATE KEY-----
vu9t0mNy8cD5x3CMVpQ/cdKpjdz46NBlcRqvJAQpO44=
-----END NEBULA X25519 PRIVATE KEY-----''',
  'ca': '''-----BEGIN NEBULA CERTIFICATE-----
CjcKBWRlYnVnKOTQlpoGMOSM9/kROiCWNJUs7c4ZRzUn2LbeAEQrz2PVswnu9dcL
Sn/2VNNu30ABEkCQtWxmCJqBr5Yd9vtDWCPo/T1JQmD3stBozcM6aUl1hP3zjURv
MAIH7gzreMGgrH/yR6rZpIHR3DxJ3E0aHtEI
-----END NEBULA CERTIFICATE-----''',
};

class MainScreen extends StatefulWidget {
  const MainScreen(this.dnEnrollStream, {Key? key}) : super(key: key);

  final StreamController dnEnrollStream;

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  List<Site>? sites;
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
    Widget? debugSite;

    if (kDebugMode) {
      debugSite = Row(
        children: [
          _debugSave(badDebugSave),
          _debugSave(goodDebugSave),
          _debugClearKeys(),
        ],
        mainAxisAlignment: MainAxisAlignment.center,
      );
    }

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
      scrollController: scrollController,
      leadingAction: PlatformIconButton(
        padding: EdgeInsets.zero,
        icon: Icon(Icons.add, size: 28.0),
        onPressed: () => Utils.openPage(context, (context) {
          return SiteConfigScreen(
              onSave: (_) {
                _loadSites();
              },
              supportsQRScanning: supportsQRScanning);
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
          onPressed: () => Utils.openPage(context, (_) => SettingsScreen(widget.dnEnrollStream)),
        ),
      ],
      bottomBar: debugSite,
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (error != null) {
      return Center(
          child: Padding(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: error!,
              ),
              padding: EdgeInsets.symmetric(vertical: 0, horizontal: 10)));
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
              Text('You don\'t have any site configurations installed yet. Hit the plus button above to get started.',
                  textAlign: TextAlign.center),
            ],
          ),
        ));
  }

  Widget _buildSites() {
    if (sites == null || sites!.length == 0) {
      return _buildNoSites();
    }

    List<Widget> items = [];
    sites!.forEach((site) {
      items.add(SiteItem(
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
          }));
    });

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
            final Site moved = sites!.removeAt(oldI);
            sites!.insert(newI, moved);
          });

          for (var i = 0; i < sites!.length; i++) {
            if (sites![i].sortKey == i) {
              continue;
            }

            sites![i].sortKey = i;
            try {
              await sites![i].save();
            } catch (err) {
              //TODO: display error at the end
              print('ERR ${sites![i].name} - $err');
            }
          }

          _loadSites();
        });

    if (Platform.isIOS) {
      child = CupertinoTheme(child: child, data: CupertinoTheme.of(context));
    }

    // The theme here is to remove the hardcoded canvas border reordering forces on us
    return Theme(data: Theme.of(context).copyWith(canvasColor: Colors.transparent), child: child);
  }

  Widget _debugSave(Map<String, String> siteConfig) {
    return CupertinoButton(
      child: Text(siteConfig['name']!),
      onPressed: () async {
        var uuid = Uuid();

        var s = Site(
            name: siteConfig['name']!,
            id: uuid.v4(),
            staticHostmap: {
              "10.1.0.1": StaticHost(
                  lighthouse: true,
                  destinations: [IPAndPort(ip: '10.1.1.53', port: 4242), IPAndPort(ip: '1::1', port: 4242)])
            },
            ca: [CertificateInfo.debug(rawCert: siteConfig['ca'])],
            certInfo: CertificateInfo.debug(rawCert: siteConfig['cert']),
            unsafeRoutes: [UnsafeRoute(route: '10.3.3.3/32', via: '10.1.0.1')]);

        s.key = siteConfig['key'];

        var err = await s.save();
        if (err != null) {
          Utils.popError(context, "Failed to save the site", err);
        } else {
          _loadSites();
        }
      },
    );
  }

  Widget _debugClearKeys() {
    return CupertinoButton(
      child: Text("Clear Keys"),
      onPressed: () async {
        await platform.invokeMethod("debug.clearKeys", null);
      },
    );
  }

  _loadSites() async {
    //TODO: This can throw, we need to show an error dialog
    Map<String, dynamic> rawSites = jsonDecode(await platform.invokeMethod('listSites'));

    sites = [];
    rawSites.forEach((id, rawSite) {
      try {
        var site = Site.fromJson(rawSite);

        //TODO: we need to cancel change listeners when we rebuild
        site.onChange().listen((_) {
          setState(() {});
        }, onError: (err) {
          setState(() {});
          if (ModalRoute.of(context)!.isCurrent) {
            Utils.popError(context, "${site.name} Error", err);
          }
        });

        sites!.add(site);
      } catch (err) {
        //TODO: handle error
        print("$err site config: $rawSite");
        // Sometimes it is helpful to just nuke these is dev
        // platform.invokeMethod('deleteSite', id);
      }
    });

    if (Platform.isAndroid) {
      // Android suffers from a race to discover the active site and attach site specific event listeners
      platform.invokeMethod("android.registerActiveSite");
    }

    sites!.sort((a, b) {
      if (a.sortKey == b.sortKey) {
        return a.name.compareTo(b.name);
      }

      return a.sortKey - b.sortKey;
    });

    setState(() {});
  }
}
