import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:logging/logging.dart';
import 'package:mobile_nebula/components/simple_page.dart';
import 'package:mobile_nebula/components/site_item.dart';
import 'package:mobile_nebula/models/site.dart';
import 'package:mobile_nebula/screens/settings_screen.dart';
import 'package:mobile_nebula/screens/siteConfig/site_config_screen.dart';
import 'package:mobile_nebula/screens/site_detail_screen.dart';
import 'package:mobile_nebula/services/utils.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:uuid/uuid.dart';
import 'package:yaml/yaml.dart';

import '../models/certificate.dart';
import '../models/ip_and_port.dart';
import '../models/static_hosts.dart';
import '../models/unsafe_route.dart';
import 'enrollment_screen.dart';

final _log = Logger('main_screen');

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
        _log.severe('unexpected method call ${call.method}', StackTrace.current);
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
        onPressed: () => showModalBottomSheet(
          context: context,
          useRootNavigator: true,
          useSafeArea: true,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          isScrollControlled: true,
          builder: _buildAddSite,
        ),
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
          onPressed: () => Utils.openPage(context, (_) => SettingsScreen()),
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
              'You don\'t have any site configurations installed yet. Tap the plus button above to get started.',
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
          } catch (err, stackTrace) {
            //TODO: display error at the end
            _log.severe('error while saving site: ${sites[i].name} (${sites[i].id})', err, stackTrace);
          }
        }

        _loadSites();
      },
    );

    if (Platform.isIOS) {
      child = CupertinoTheme(data: CupertinoTheme.of(context), child: child);
    }

    // The theme here is to remove the hardcoded canvas border reordering forces on us
    return Theme(
      data: Theme.of(context).copyWith(canvasColor: Colors.transparent),
      child: child,
    );
  }

  Widget _buildAddSite(BuildContext context) {
    final arrowIcon = Icon(
      Icons.arrow_forward_ios,
      size: 18,
      color: Theme.of(context).listTileTheme.leadingAndTrailingTextStyle!.color,
    );

    final outerContext = this.context;
    final children = [
      ListTile(
        title: Text('From scratch'),
        subtitle: Text('Manually configure new network'),
        trailing: arrowIcon,
        onTap: () {
          // Remove the modal
          Navigator.pop(context);

          // Open the new site page
          Utils.openPage(context, (context) {
            return SiteConfigScreen(
              onSave: (_) {
                _loadSites();
              },
              supportsQRScanning: supportsQRScanning,
            );
          });
        },
      ),
      ListTile(
        title: Text('From file'),
        subtitle: Text('Import YAML configuration'),
        trailing: arrowIcon,
        onTap: () async {
          try {
            // Remove the modal
            Navigator.pop(context);

            final rawContent = await Utils.pickFile(context);
            if (rawContent == null) {
              return Utils.popError('Load YAML config', 'File was empty');
            }
            final yaml = loadYaml(rawContent);
            final site = await Site.fromYaml(yaml);
            if (!outerContext.mounted) {
              return;
            }

            Utils.openPage(outerContext, (context) {
              return SiteConfigScreen(
                site: site,
                onSave: (_) {
                  _loadSites();
                },
                supportsQRScanning: supportsQRScanning,
                startChanged: true,
              );
            });
          } catch (err) {
            return Utils.popError('Load YAML config', err.toString());
          }
        },
      ),
      ListTile(
        title: Text('Enroll with defined.net'),
        subtitle: Text('Join your organizations network'),
        trailing: arrowIcon,
        onTap: () =>
            Utils.openPage(context, (context) => EnrollmentScreen(stream: widget.dnEnrollStream, allowCodeEntry: true)),
      ),
    ];

    if (kDebugMode) {
      children.add(_debugSave(badDebugSave));
      children.add(_debugSave(goodDebugSave));
      children.add(_debugSave(goodDebugSaveV2));
      children.add(_debugSave(goodDebugSaveV2P256));
      children.add(_debugClearKeys());
    }

    final borderColor = Theme.of(context).colorScheme.outlineVariant;

    return DraggableScrollableSheet(
      expand: false,
      builder: (context, scrollController) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsetsGeometry.all(32),
              child: Text('Add Site', style: Theme.of(context).listTileTheme.titleTextStyle!.copyWith(fontSize: 18)),
            ),
            Flexible(
              child: SafeArea(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsetsGeometry.fromLTRB(32, 0, 32, 32),
                  children: List.generate(children.length, (index) {
                    final borderSide = BorderSide(color: borderColor);
                    if (index == 0) {
                      return Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          border: Border(top: borderSide, left: borderSide, right: borderSide),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                        child: children[index],
                      );
                    }

                    if (index == children.length - 1) {
                      return Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          border: Border.fromBorderSide(borderSide),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: children[index],
                      );
                    }

                    // return children[index];
                    return Container(
                      clipBehavior: Clip.antiAlias, // and here
                      decoration: BoxDecoration(
                        border: Border(top: borderSide, left: borderSide, right: borderSide),
                      ),
                      child: children[index],
                    );
                  }),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  ListTile _debugSave(Map<String, String> siteConfig) {
    return ListTile(
      title: Text(siteConfig['name']!),
      onTap: () async {
        var uuid = Uuid();

        var s = Site(
          name: siteConfig['name']!,
          id: uuid.v4(),
          staticHostmap: {
            "10.1.0.1": StaticHost(
              lighthouse: true,
              destinations: [IPAndPort('10.1.1.53', 4242), IPAndPort('1::1', 4242)],
            ),
          },
          ca: [CertificateInfo.debug(rawCert: siteConfig['ca'])],
          certInfo: CertificateInfo.debug(rawCert: siteConfig['cert']),
          unsafeRoutes: [UnsafeRoute(route: '10.3.3.3/32', via: '10.1.0.1')],
        );

        s.key = siteConfig['key'];

        try {
          await s.save();
          _loadSites();
        } catch (err) {
          Utils.popError("Failed to save the site", err.toString());
        }
      },
    );
  }

  ListTile _debugClearKeys() {
    return ListTile(
      title: Text("Clear Keys"),
      onTap: () async {
        await platform.invokeMethod("debug.clearKeys", null);
        _loadSites();
      },
    );
  }

  Future<void> _loadSites() async {
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
      } catch (err, stackTrace) {
        //TODO: handle error
        _log.severe('error while hydrating a site from an incoming site', err, stackTrace);
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

/// Contains an expired v1 CA and certificate
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

/// Contains a non-expired v1 CA and certificate
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

/// Contains a non-expired v2 CA and certificate
const goodDebugSaveV2 = {
  'name': 'Good Site V2',
  'cert': '''-----BEGIN NEBULA CERTIFICATE V2-----
MIIBHKCBtYAMVjIgVGVzdCBIb3N0oTQEBQoBAAIQBAXAqAECGAQR/ZgAAAAAAAAA
AAAAAAAAAkAEEf2Z7u7u7u7uqqq7u8zM//JAohoEBQAAAAAABBEAAAAAAAAAAAAA
AAAAAAAAAKMlDAt0ZXN0LWdyb3VwMQwLdGVzdC1ncm91cDIMCWZvb2JhcmJheoUE
aQUSxIYEauZGOYcganAHTUvQcytewZBsfkiAhruIuQgoJ0vSpRK180ipgQuCIG06
ZRKG32WKsCKEls5eENf5QkUO6pzaGGgCdLl3rbRJg0Db4EhAHpvtNbumzMs2lamb
zkFjSWHl6qTvhA/3ZaKuD09wp9NEHhkL8l9uwz9KfSB6wHsZDC55i/HBo9YKCPIB
-----END NEBULA CERTIFICATE V2-----''',
  'key': '''-----BEGIN NEBULA X25519 PRIVATE KEY-----
QyQYT2IxfdtDGUirKjhUMIT5O6W8CE/JzJquqQRZhFU=
-----END NEBULA X25519 PRIVATE KEY-----''',
  'ca': '''-----BEGIN NEBULA CERTIFICATE V2-----
MIHeoHiAClYyIFRlc3QgQ0GhNAQFCgEAABAEBcCoAQAYBBH9mAAAAAAAAAAAAAAA
AAABQAQR/Znu7u7u7u4AAAAAAAAAAECjJQwLdGVzdC1ncm91cDEMC3Rlc3QtZ3Jv
dXAyDAlmb29iYXJiYXqEAf+FBGkFErqGBGrmRjqCIB1M/UJegMPjdpCkNV4spaH6
48Zrc6EF6PgB0dmTjsGug0DHOiCTMm/fRkD1R3E+gtI53eTJk/gaRyphMvSJUuyJ
Yd6DdoCpAMXb7cpgDfW8PGkU/77HWjLhu5HM28YHlioC
-----END NEBULA CERTIFICATE V2-----''',
};

/// Contains a non-expired v2 CA and certificate using curve P256
const goodDebugSaveV2P256 = {
  'name': 'Good Site V2 P256',
  'cert': '''-----BEGIN NEBULA CERTIFICATE V2-----
MIHhoFGABHRlc3ShGgQFZEAAARgEEf2ZEjQAAAAAAAAAAAAAAAFAhQRpliGlhgUB
QCnFnocg11j0TjKY5XTo6kTiHsdkHbKMgvY06sGJqj7q8IhdUAyBAQGCQQTZNYsI
x73Zk+2pddHdP2j5DbA4EweyIgSLaGHaxCy3CfWXUl91Nkm2UIsVztCNbVA1EZk0
hqotegK6OR0rIy8Gg0YwRAIgTb8NMfYsGGGUEt3R3wyRT+OojoQoelQ3+kdUZcc8
uvwCIFwKsKHPV4z2Thluktp0a1BkVE686aiSE6DJsw7dcP0b
-----END NEBULA CERTIFICATE V2-----''',
  'key': '''-----BEGIN NEBULA P256 PRIVATE KEY-----
/xIA9C3sS+xHiC2gsdgPITdvApS9zXPB98teFJr0Xho=
-----END NEBULA P256 PRIVATE KEY-----''',
  'ca': '''-----BEGIN NEBULA CERTIFICATE V2-----
MIGmoBaABHRlc3SEAf+FBGmWIZ+GBQFAKcWfgQEBgkEEs/i7EPQ1EEKzxtMNiCpY
S/PfnqOGvyvSk96N/TeuqtjYostx9V1yBCR27MT74jFM5RSgroSfuatcyJvXeSD3
TINGMEQCIC719bsgIqPMEk/c/x6bVfec9OmBac2Za1TLVRny4VsSAiBjb5IfFxde
dkbm61ltqb21JyWqsqfDbpcaCEECc20oZQ==
-----END NEBULA CERTIFICATE V2-----''',
};
