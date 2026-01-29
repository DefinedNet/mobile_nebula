import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile_nebula/services/utils.dart';

const defaultPadding = EdgeInsets.symmetric(vertical: 6, horizontal: 15);

class ConfigItem extends StatelessWidget {
  const ConfigItem({
    super.key,
    this.label,
    required this.content,
    this.labelWidth = 100,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.padding = defaultPadding,
  });

  final Widget? label;
  final Widget content;
  final double labelWidth;
  final CrossAxisAlignment crossAxisAlignment;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    TextStyle textStyle;
    if (Platform.isAndroid) {
      textStyle = Theme.of(context).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.normal);
    } else {
      textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    }

    return Container(
      color: Utils.configItemBackground(context),
      padding: padding,
      constraints: BoxConstraints(minHeight: Utils.minInteractiveSize),
      child: Row(
        crossAxisAlignment: crossAxisAlignment,
        children: <Widget>[
          SizedBox(width: labelWidth, child: DefaultTextStyle(style: textStyle, child: Container(child: label))),
          Expanded(child: DefaultTextStyle(style: textStyle, child: Container(child: content))),
        ],
      ),
    );
  }
}
