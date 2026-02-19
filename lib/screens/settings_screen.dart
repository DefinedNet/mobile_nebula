import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_nebula/components/config/config_item.dart';
import 'package:mobile_nebula/components/config/config_page_item.dart';
import 'package:mobile_nebula/components/config/config_section.dart';
import 'package:mobile_nebula/components/simple_page.dart';
import 'package:mobile_nebula/services/settings.dart';
import 'package:mobile_nebula/services/utils.dart';

import 'about_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

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
          ConfigPageItem(label: Text('About'), onPressed: () => Utils.openPage(context, (context) => AboutScreen())),
        ],
      ),
    );

    return SimplePage(
      title: Text('Settings'),
      child: Column(children: items),
    );
  }
}
