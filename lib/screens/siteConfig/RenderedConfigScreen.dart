import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:mobile_nebula/components/SimplePage.dart';
import 'package:mobile_nebula/services/share.dart';

class RenderedConfigScreen extends StatelessWidget {
  final String config;
  final String name;

  RenderedConfigScreen({Key key, this.config, this.name}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      title: 'Rendered Site Config',
      scrollable: SimpleScrollable.both,
      trailingActions: <Widget>[
        PlatformIconButton(
          padding: EdgeInsets.zero,
          icon: Icon(context.platformIcons.share, size: 28.0),
          onPressed: () => Share.share(title: '$name.yaml', text: config, filename: '$name.yaml'),
        )
      ],
      child: Container(
          padding: EdgeInsets.all(5),
          constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
          child: SelectableText(config, style: TextStyle(fontFamily: 'RobotoMono', fontSize: 14))),
    );
  }
}
