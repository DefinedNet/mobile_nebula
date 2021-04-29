import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

TextStyle basicTextStyle(BuildContext context) =>
    Platform.isIOS ? CupertinoTheme.of(context).textTheme.textStyle : Theme.of(context).textTheme.subtitle1;

const double _headerFontSize = 13.0;

class ConfigHeader extends StatelessWidget {
  const ConfigHeader({Key key, this.label, this.color}) : super(key: key);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 10.0, top: 30.0, bottom: 5.0, right: 10.0),
      child: Text(
        label,
        style: basicTextStyle(context).copyWith(
          color: color ?? CupertinoColors.secondaryLabel.resolveFrom(context),
          fontSize: _headerFontSize,
        ),
      ),
    );
  }
}
