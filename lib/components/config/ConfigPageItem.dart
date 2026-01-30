import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile_nebula/components/SpecialButton.dart';
import 'package:mobile_nebula/services/utils.dart';

const defaultPadding = EdgeInsets.symmetric(vertical: 6, horizontal: 15);

class ConfigPageItem extends StatelessWidget {
  const ConfigPageItem({
    super.key,
    this.label,
    this.content,
    this.labelWidth = 100,
    this.onPressed,
    this.disabled = false,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.padding = defaultPadding,
  });

  final Widget? label;
  final Widget? content;
  final double labelWidth;
  final CrossAxisAlignment crossAxisAlignment;
  final void Function()? onPressed;
  final bool disabled;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    dynamic theme;

    if (Platform.isAndroid) {
      final origTheme = Theme.of(context);
      theme = origTheme.copyWith(
        textTheme: origTheme.textTheme.copyWith(
          labelLarge: origTheme.textTheme.labelLarge!.copyWith(fontWeight: FontWeight.normal),
        ),
      );
      return Theme(data: theme, child: _buildContent(context));
    } else {
      final origTheme = CupertinoTheme.of(context);
      theme = origTheme.copyWith(primaryColor: CupertinoColors.label.resolveFrom(context));
      return CupertinoTheme(data: theme, child: _buildContent(context));
    }
  }

  Widget _buildContent(BuildContext context) {
    return SpecialButton(
      onPressed: disabled ? null : onPressed,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Container(
        padding: padding,
        constraints: BoxConstraints(minHeight: Utils.minInteractiveSize, minWidth: double.infinity),
        child: Row(
          crossAxisAlignment: crossAxisAlignment,
          children: <Widget>[
            label != null ? SizedBox(width: labelWidth, child: label) : Container(),
            Expanded(child: Container(padding: EdgeInsets.only(right: 10), child: content)),
            disabled
                ? Container()
                : Icon(Icons.arrow_forward_ios, color: CupertinoColors.placeholderText.resolveFrom(context), size: 18),
          ],
        ),
      ),
    );
  }
}
