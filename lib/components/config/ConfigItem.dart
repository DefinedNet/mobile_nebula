import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile_nebula/services/utils.dart';

class ConfigItem extends StatelessWidget {
  const ConfigItem(
      {Key? key, this.label, required this.content, this.labelWidth = 100, this.crossAxisAlignment = CrossAxisAlignment.center})
      : super(key: key);

  final Widget? label;
  final Widget content;
  final double labelWidth;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return Container(
        color: Utils.configItemBackground(context),
        padding: EdgeInsets.only(top: 2, bottom: 2, left: 15, right: 10),
        constraints: BoxConstraints(minHeight: Utils.minInteractiveSize),
        child: Row(
          crossAxisAlignment: crossAxisAlignment,
          children: <Widget>[
            Container(width: labelWidth, child: label),
            Expanded(child: content),
          ],
        ));
  }
}
