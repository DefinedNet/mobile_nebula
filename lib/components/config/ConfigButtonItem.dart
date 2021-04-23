import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:mobile_nebula/components/SpecialButton.dart';
import 'package:mobile_nebula/services/utils.dart';

// A config item that detects tapping and calls back on a tap
class ConfigButtonItem extends StatelessWidget {
  const ConfigButtonItem({Key key, this.content, this.onPressed}) : super(key: key);

  final Widget content;
  final onPressed;

  @override
  Widget build(BuildContext context) {
    return SpecialButton(
        color: Utils.configItemBackground(context),
        onPressed: onPressed,
        useButtonTheme: true,
        child: Container(
          constraints: BoxConstraints(minHeight: Utils.minInteractiveSize, minWidth: double.infinity),
          child: Center(child: content),
        ));
  }
}
