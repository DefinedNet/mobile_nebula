import 'dart:async';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_nebula/components/SimplePage.dart';
import 'package:mobile_nebula/components/config/ConfigItem.dart';
import 'package:mobile_nebula/components/config/ConfigPageItem.dart';
import 'package:mobile_nebula/components/config/ConfigSection.dart';
import 'package:mobile_nebula/screens/EnrollmentScreen.dart';
import 'package:mobile_nebula/services/oidc.dart';
import 'package:mobile_nebula/services/settings.dart';
import 'package:mobile_nebula/services/utils.dart';

import 'AboutScreen.dart';

class SettingsScreen extends StatefulWidget {
  final StreamController stream;

  const SettingsScreen(this.stream, {super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  var settings = Settings();
  static const platform = MethodChannel('net.defined.mobileNebula/NebulaVpnService');
  static const bgplatform = MethodChannel('net.defined.mobileNebula/NebulaVpnService/background');
  late final OIDCPoller _authService = OIDCPoller(settings, platform, bgplatform);

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
          ConfigPageItem(
            label: Text('Enroll with Managed Nebula (SSO)'),
            labelWidth: 250,
            onPressed: () => onEnrollSSO(),
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

    return SimplePage(title: Text('Settings'), child: Column(children: items));
  }

  Future<void> onEnrollSSO() async {
    try {
      final success = await _authService.beginLogin();

      if (!success) {
        print("Failed to open login page");
        return;
      }

      print("Waiting for login...");
      final status = await _authService.pollLoop();
      if (!mounted) return;
      if (status == true) {
        // Login successful, go home
        Navigator.of(context).pop();
      } else {
        print("login failed");
      }
    } catch (e) {
      print("login failed with exception: $e");
    }
  }
}
