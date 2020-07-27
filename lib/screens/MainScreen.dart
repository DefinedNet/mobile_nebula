import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
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
import 'package:uuid/uuid.dart';

//TODO: add refresh

class MainScreen extends StatefulWidget {
  const MainScreen({Key key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool ready = false;
  List<Site> sites;

  static const platform = MethodChannel('net.defined.mobileNebula/NebulaVpnService');

  @override
  void initState() {
    _loadSites();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      title: 'Nebula',
      scrollable: SimpleScrollable.none,
      leadingAction: PlatformIconButton(
        padding: EdgeInsets.zero,
        icon: Icon(Icons.add, size: 28.0),
        onPressed: () => Utils.openPage(context, (context) {
          return SiteConfigScreen(onSave: (_) {
            _loadSites();
          });
        }),
      ),
      trailingActions: <Widget>[
        PlatformIconButton(
          padding: EdgeInsets.zero,
          icon: Icon(Icons.menu, size: 28.0),
          onPressed: () => Utils.openPage(context, (_) => SettingsScreen()),
        ),
      ],
      bottomBar: kDebugMode ? _debugSave() : null,
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!ready) {
      return Center(
        child: PlatformCircularProgressIndicator(ios: (_) {
          return CupertinoProgressIndicatorData(radius: 50);
        }),
      );
    }

    if (sites == null || sites.length == 0) {
      return _buildNoSites();
    }

    return _buildSites();
  }

  Widget _buildNoSites() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
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
    );
  }

  Widget _buildSites() {
    List<Widget> items = [];
    sites.forEach((site) {
      items.add(SiteItem(
          key: Key(site.id),
          site: site,
          onPressed: () {
            Utils.openPage(context, (context) {
              return SiteDetailScreen(site: site, onChanged: () => _loadSites());
            });
          }));
    });

    Widget child = ReorderableListView(
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

          for (var i = min(oldI, newI); i <= max(oldI, newI); i++) {
            sites[i].sortKey = i;
            try {
              await sites[i].save();
            } catch (err) {
              //TODO: display error at the end
              print('ERR ${sites[i].name} - $err');
            }
          }

          _loadSites();
        });

    if (Platform.isIOS) {
      child = CupertinoTheme(child: child, data: CupertinoTheme.of(context));
    }

    // The theme here is to remove the hardcoded canvas border reordering forces on us
    return Theme(
        data: Theme.of(context).copyWith(canvasColor: Colors.transparent),
        child: child
    );
  }

  Widget _debugSave() {
    return CupertinoButton(
      key: Key('debug-save'),
      child: Text("DEBUG SAVE"),
      onPressed: () async {
        var uuid = Uuid();

        var cert = '''-----BEGIN NEBULA CERTIFICATE-----
CmMKBnBpeGVsNBIJiYCEUID+//8PKLqMivcFMKTzjoYGOiB4iANINzCjLdlQJSj/
vJDd080yggfLgW9hT4a/bhGZekog+W+YEJiV36evX4MueQ+npDzJd3zGg5gialu4
UNGYBP0SQL5bjEyafC0YtETEbrraSfwuFHMvUoi1Kc4XRzTPPvHsEaq3hNNTZtD7
Pt3sjH83zTMZfnD/Du3ahsvV0rAXUgc=
-----END NEBULA CERTIFICATE-----''';

        var ca = '''-----BEGIN NEBULA CERTIFICATE-----
CjkKB3Rlc3QgY2EopYyK9wUwpfOOhgY6IHj4yrtHbq+rt4hXTYGrxuQOS0412uKT
4wi5wL503+SAQAESQPhWXuVGjauHS1Qqd3aNA3DY+X8CnAweXNEoJKAN/kjH+BBv
mUOcsdFcCZiXrj7ryQIG1+WfqA46w71A/lV4nAc=
-----END NEBULA CERTIFICATE-----''';

        var s = Site(
          name: "DEBUG TEST",
          id: uuid.v4(),
          staticHostmap: {
            "10.1.0.1": StaticHost(lighthouse: true, destinations: [IPAndPort(ip: '10.1.1.53', port: 4242)])
          },
          ca: [CertificateInfo.debug(rawCert: ca)],
          cert: CertificateInfo.debug(rawCert: cert),
          unsafeRoutes: [UnsafeRoute(route: '10.3.3.3/32', via: '10.1.0.1')]
        );

        s.key = "-----BEGIN NEBULA X25519 PRIVATE KEY-----\ndYgPb04Bb1xzfgdCfVsKGZrCYe+u5tDWNXKipQBVZ44=\n-----END NEBULA X25519 PRIVATE KEY-----";

        var err = await s.save();
        if (err != null) {
          Utils.popError(context, "Failed to save the site", err);
        } else {
          _loadSites();
        }
      },
    );
  }

  _loadSites() async {
    if (Platform.isAndroid) {
      await platform.invokeMethod("android.requestPermissions");
    }

    //TODO: This can throw, we need to show an error dialog
    Map<String, dynamic> rawSites = jsonDecode(await platform.invokeMethod('listSites'));
    bool hasErrors = false;

    sites = [];
    rawSites.values.forEach((rawSite) {
      try {
        var site = Site.fromJson(rawSite);
        if (site.errors.length > 0) {
          hasErrors = true;
        }

        //TODO: we need to cancel change listeners when we rebuild
        site.onChange().listen((_) {
          setState(() {});
        }, onError: (err) {
          setState(() {});
          if (ModalRoute.of(context).isCurrent) {
            Utils.popError(context, "${site.name} Error", err);
          }
        });

        sites.add(site);
      } catch (err) {
        //TODO: handle error
        print(err);
      }
    });

    if (hasErrors) {
      Utils.popError(context, "Site Error(s)", "1 or more sites have errors and need your attention, problem sites have a red border.");
    }

    sites.sort((a, b) {
      return a.sortKey - b.sortKey;
    });

    setState(() {
      ready = true;
    });
  }
}
