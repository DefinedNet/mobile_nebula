import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:mobile_nebula/components/SimplePage.dart';
import 'package:mobile_nebula/services/share.dart';

class RenderedConfigScreen extends StatelessWidget {
  final String config;
  final String name;

  const RenderedConfigScreen({super.key, required this.config, required this.name});

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      title: Text('Rendered Site Config'),
      scrollable: SimpleScrollable.both,
      trailingActions: <Widget>[
        Builder(
          builder: (BuildContext context) {
            return PlatformIconButton(
              padding: EdgeInsets.zero,
              icon: Icon(context.platformIcons.share, size: 28.0),
              onPressed: () => Share.share(context, title: '$name.yaml', text: config, filename: '$name.yaml'),
            );
          },
        ),
      ],
      child: Container(
        padding: EdgeInsets.all(5),
        constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
        child: SelectableText(config, style: TextStyle(fontFamily: 'RobotoMono', fontSize: 14)),
      ),
    );
  }
}
