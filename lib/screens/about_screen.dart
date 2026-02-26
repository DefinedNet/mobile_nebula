import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:mobile_nebula/components/config/config_item.dart';
import 'package:mobile_nebula/components/config/config_page_item.dart';
import 'package:mobile_nebula/components/config/config_section.dart';
import 'package:mobile_nebula/components/simple_page.dart';
import 'package:mobile_nebula/gen.versions.dart';
import 'package:mobile_nebula/screens/licenses_screen.dart';
import 'package:mobile_nebula/services/utils.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  AboutScreenState createState() => AboutScreenState();
}

class AboutScreenState extends State<AboutScreen> {
  bool ready = false;
  PackageInfo? packageInfo;

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
    // packageInfo is null until ready is true
    if (!ready) {
      return Center(
        child: PlatformCircularProgressIndicator(
          cupertino: (_, _) {
            return CupertinoProgressIndicatorData(radius: 50);
          },
        ),
      );
    }

    return SimplePage(
      title: Text('About'),
      child: Column(
        children: [
          ConfigSection(
            children: <Widget>[
              ConfigItem(
                label: Text('App version'),
                labelWidth: 150,
                content: _buildText('${packageInfo!.version}-${packageInfo!.buildNumber} (sha: $gitSha)'),
              ),
              ConfigItem(
                label: Text('Nebula version'),
                labelWidth: 150,
                content: _buildText('$nebulaVersion ($goVersion)'),
              ),
              ConfigItem(
                label: Text('Flutter version'),
                labelWidth: 150,
                content: _buildText(flutterVersion['frameworkVersion'] ?? 'Unknown'),
              ),
              ConfigItem(
                label: Text('Dart version'),
                labelWidth: 150,
                content: _buildText(flutterVersion['dartSdkVersion'] ?? 'Unknown'),
              ),
            ],
          ),
          ConfigSection(
            children: <Widget>[
              //TODO: wire up these other pages
              //          ConfigPageItem(label: Text('Changelog'), labelWidth: 300, onPressed: () => Utils.launchUrl('https://defined.net/mobile/changelog', context)),
              ConfigPageItem(
                label: Text('Privacy policy'),
                onPressed: () => Utils.launchUrl('https://www.defined.net/privacy/'),
              ),
              ConfigPageItem(
                label: Text('Licenses'),
                onPressed: () => Utils.openPage(context, (context) {
                  return LicensesScreen();
                }),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(top: 20),
            child: Text('Copyright © 2026 Defined Networking, Inc', textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Align _buildText(String str) {
    return Align(alignment: AlignmentDirectional.centerEnd, child: SelectableText(str));
  }
}
