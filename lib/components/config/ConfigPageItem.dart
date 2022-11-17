import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile_nebula/components/SpecialButton.dart';
import 'package:mobile_nebula/services/utils.dart';

class ConfigPageItem extends StatelessWidget {
  const ConfigPageItem(
      {Key? key,
      this.label,
      this.content,
      this.labelWidth = 100,
      this.onPressed,
      this.disabled = false,
      this.crossAxisAlignment = CrossAxisAlignment.center})
      : super(key: key);

  final Widget? label;
  final Widget? content;
  final double labelWidth;
  final CrossAxisAlignment crossAxisAlignment;
  final onPressed;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    var theme;

    if (Platform.isAndroid) {
      final origTheme = Theme.of(context);
      theme = origTheme.copyWith(
          textTheme: origTheme.textTheme
              .copyWith(button: origTheme.textTheme.button!.copyWith(fontWeight: FontWeight.normal)));
      return Theme(data: theme, child: _buildContent(context));
    } else {
      final origTheme = CupertinoTheme.of(context);
      theme = origTheme.copyWith(primaryColor: CupertinoColors.label.resolveFrom(context));
      return CupertinoTheme(data: theme, child: _buildContent(context));
    }
  }

  Widget _buildContent(BuildContext context) {
    return SpecialButton(
      onPressed: this.disabled ? null : onPressed,
      color: Utils.configItemBackground(context),
      child: Container(
          padding: EdgeInsets.only(left: 15),
          constraints: BoxConstraints(minHeight: Utils.minInteractiveSize, minWidth: double.infinity),
          child: Row(
            crossAxisAlignment: crossAxisAlignment,
            children: <Widget>[
              label != null ? Container(width: labelWidth, child: label) : Container(),
              Expanded(child: Container(child: content, padding: EdgeInsets.only(right: 10))),
              this.disabled ? Container() : Icon(CupertinoIcons.forward, color: CupertinoColors.placeholderText.resolveFrom(context), size: 18)
            ],
          )),
    );
  }
}
