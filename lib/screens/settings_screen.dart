import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_nebula/components/config/config_item.dart';
import 'package:mobile_nebula/components/config/config_page_item.dart';
import 'package:mobile_nebula/components/config/config_section.dart';
import 'package:mobile_nebula/components/simple_page.dart';
import 'package:mobile_nebula/screens/enrollment_screen.dart';
import 'package:mobile_nebula/services/settings.dart';
import 'package:mobile_nebula/services/utils.dart';
import 'package:uuid/uuid.dart';

import '../models/certificate.dart';
import '../models/ip_and_port.dart';
import '../models/site.dart';
import '../models/static_hosts.dart';
import '../models/unsafe_route.dart';
import 'about_screen.dart';

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

class SettingsScreen extends StatefulWidget {
  final StreamController stream;
  final Function? onDebugChanged;

  const SettingsScreen(this.stream, this.onDebugChanged, {super.key});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  var settings = Settings();
  static const platform = MethodChannel('net.defined.mobileNebula/NebulaVpnService');

  @override
  void initState() {
    //TODO: we need to unregister on dispose?
    settings.onChange().listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> colorSection = [];
    Widget? debugSite;

    if (kDebugMode) {
      debugSite = Wrap(
        alignment: WrapAlignment.center,
        children: [_debugSave(badDebugSave), _debugSave(goodDebugSave), _debugSave(goodDebugSaveV2), _debugClearKeys()],
      );
    }

    colorSection.add(
      ConfigItem(
        label: Text('Use system colors'),
        labelWidth: 200,
        content: Align(
          alignment: Alignment.centerRight,
          child: Switch.adaptive(
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: (value) {
              settings.useSystemColors = value;
            },
            value: settings.useSystemColors,
          ),
        ),
      ),
    );

    if (!settings.useSystemColors) {
      colorSection.add(
        ConfigItem(
          label: Text('Dark mode'),
          content: Align(
            alignment: Alignment.centerRight,
            child: Switch.adaptive(
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (value) {
                settings.darkMode = value;
              },
              value: settings.darkMode,
            ),
          ),
        ),
      );
    }

    List<Widget> items = [];
    items.add(ConfigSection(children: colorSection));
    items.add(
      ConfigItem(
        label: Text('Wrap log output'),
        labelWidth: 200,
        content: Align(
          alignment: Alignment.centerRight,
          child: Switch.adaptive(
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            value: settings.logWrap,
            onChanged: (value) {
              setState(() {
                settings.logWrap = value;
              });
            },
          ),
        ),
      ),
    );

    items.add(
      ConfigSection(
        children: [
          ConfigItem(
            label: Text('Report errors automatically'),
            labelWidth: 250,
            content: Align(
              alignment: Alignment.centerRight,
              child: Switch.adaptive(
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                value: settings.trackErrors,
                onChanged: (value) {
                  setState(() {
                    settings.trackErrors = value;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );

    items.add(
      ConfigSection(
        children: [
          ConfigPageItem(
            label: Text('Enroll with Managed Nebula'),
            labelWidth: 250,
            onPressed:
                () =>
                    Utils.openPage(context, (context) => EnrollmentScreen(stream: widget.stream, allowCodeEntry: true)),
          ),
        ],
      ),
    );

    items.add(
      ConfigSection(
        children: [
          ConfigPageItem(label: Text('About'), onPressed: () => Utils.openPage(context, (context) => AboutScreen())),
        ],
      ),
    );

    return SimplePage(title: Text('Settings'), bottomBar: debugSite, child: Column(children: items));
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
              destinations: [IPAndPort(ip: '10.1.1.53', port: 4242), IPAndPort(ip: '1::1', port: 4242)],
            ),
          },
          ca: [CertificateInfo.debug(rawCert: siteConfig['ca'])],
          certInfo: CertificateInfo.debug(rawCert: siteConfig['cert']),
          unsafeRoutes: [UnsafeRoute(route: '10.3.3.3/32', via: '10.1.0.1')],
        );

        s.key = siteConfig['key'];

        try {
          await s.save();
          widget.onDebugChanged?.call();
        } catch (err) {
          Utils.popError("Failed to save the site", err.toString());
        }
      },
    );
  }

  Widget _debugClearKeys() {
    return CupertinoButton(
      child: Text("Clear Keys"),
      onPressed: () async {
        await platform.invokeMethod("debug.clearKeys", null);
        widget.onDebugChanged?.call();
      },
    );
  }
}
