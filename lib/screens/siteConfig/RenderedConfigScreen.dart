import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile_nebula/components/SimplePage.dart';

class RenderedConfigScreen extends StatelessWidget {
  final String config;

  RenderedConfigScreen({Key key, this.config}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      title: 'Rendered Site Config',
      scrollable: SimpleScrollable.both,
      child: Container(
          padding: EdgeInsets.all(5),
          constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
          child: SelectableText(config, style: TextStyle(fontFamily: 'RobotoMono', fontSize: 14))),
    );
  }
}
