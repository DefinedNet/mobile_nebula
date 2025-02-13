import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile_nebula/services/utils.dart';

class ConfigItem extends StatelessWidget {
  const ConfigItem({
    Key? key,
    this.label,
    required this.content,
    this.labelWidth = 100,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  }) : super(key: key);

  final Widget? label;
  final Widget content;
  final double labelWidth;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    var textStyle;
    if (Platform.isAndroid) {
      textStyle = Theme.of(context).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.normal);
    } else {
      textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    }

    return Container(
      color: Utils.configItemBackground(context),
      padding: EdgeInsets.symmetric(vertical: 6, horizontal: 15),
      constraints: BoxConstraints(minHeight: Utils.minInteractiveSize),
      child: Row(
        crossAxisAlignment: crossAxisAlignment,
        children: <Widget>[
          Container(width: labelWidth, child: DefaultTextStyle(style: textStyle, child: Container(child: label))),
          Expanded(child: DefaultTextStyle(style: textStyle, child: Container(child: content))),
        ],
      ),
    );
  }
}
