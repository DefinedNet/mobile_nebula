import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:mobile_nebula/components/SimplePage.dart';
import 'package:mobile_nebula/components/config/ConfigItem.dart';
import 'package:mobile_nebula/components/config/ConfigPageItem.dart';
import 'package:mobile_nebula/components/config/ConfigSection.dart';
import 'package:mobile_nebula/gen.versions.dart';
import 'package:mobile_nebula/services/utils.dart';
import 'package:package_info/package_info.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({Key key}) : super(key: key);

  @override
  _AboutScreenState createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  bool ready = false;
  PackageInfo packageInfo;

  @override
  void initState() {
    PackageInfo.fromPlatform().then((PackageInfo info) {
      packageInfo = info;
      setState(() {
        ready = true;
      });
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) {
      return Center(
        child: PlatformCircularProgressIndicator(cupertino: (_, __) {
          return CupertinoProgressIndicatorData(radius: 50);
        }),
      );
    }

    return SimplePage(
      title: 'About',
      child: Column(children: [
        ConfigSection(children: <Widget>[
          ConfigItem(
              label: Text('App version'),
              labelWidth: 150,
              content: _buildText('${packageInfo.version}-${packageInfo.buildNumber} (sha: $gitSha)')),
          ConfigItem(
              label: Text('Nebula version'), labelWidth: 150, content: _buildText('$nebulaVersion ($goVersion)')),
          ConfigItem(
              label: Text('Flutter version'), labelWidth: 150, content: _buildText(flutterVersion['frameworkVersion'])),
          ConfigItem(
              label: Text('Dart version'), labelWidth: 150, content: _buildText(flutterVersion['dartSdkVersion'])),
        ]),
        ConfigSection(children: <Widget>[
          //TODO: wire up these other pages
//          ConfigPageItem(label: Text('Changelog'), labelWidth: 300, onPressed: () => Utils.launchUrl('https://defined.net/mobile/changelog', context)),
          ConfigPageItem(
              label: Text('Privacy policy'),
              labelWidth: 300,
              onPressed: () => Utils.launchUrl('https://defined.net/privacy-policy', context)),
//          ConfigPageItem(label: Text('Licenses'), labelWidth: 300, onPressed: () => Utils.launchUrl('https://defined.net/mobile/license', context)),
        ]),
        Padding(
            padding: EdgeInsets.only(top: 20),
            child: Text(
              'Copyright © 2020 Defined Networking, Inc',
              textAlign: TextAlign.center,
            )),
      ]),
    );
  }

  _buildText(String str) {
    return Align(alignment: AlignmentDirectional.centerEnd, child: SelectableText(str));
  }
}
