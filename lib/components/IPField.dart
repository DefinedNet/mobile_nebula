import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:mobile_nebula/components/SpecialTextField.dart';
import '../services/utils.dart';

class IPField extends StatelessWidget {
  final String help;
  final bool ipOnly;
  final bool autoFocus;
  final FocusNode focusNode;
  final FocusNode nextFocusNode;
  final ValueChanged<String> onChanged;
  final EdgeInsetsGeometry textPadding;
  final TextInputAction textInputAction;
  final controller;
  final textAlign;

  const IPField(
      {Key key,
      this.ipOnly = false,
      this.help = "ip address",
      this.autoFocus = false,
      this.focusNode,
      this.nextFocusNode,
      this.onChanged,
      this.textPadding = const EdgeInsets.all(6.0),
      this.textInputAction,
      this.controller,
      this.textAlign = TextAlign.center})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    var textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    final double ipWidth = ipOnly ? Utils.textSize("000000000000000", textStyle).width + 12 : null;

    return SizedBox(
        width: ipWidth,
        child: SpecialTextField(
          keyboardType: ipOnly ? TextInputType.numberWithOptions(decimal: true) : null,
          textAlign: textAlign,
          autofocus: autoFocus,
          focusNode: focusNode,
          nextFocusNode: nextFocusNode,
          controller: controller,
          onChanged: onChanged,
          maxLength: ipOnly ? 15 : null,
          maxLengthEnforced: ipOnly ? true : false,
          inputFormatters: ipOnly
              ? [WhitelistingTextInputFormatter(RegExp(r'[\d\.]+'))]
              : [WhitelistingTextInputFormatter(RegExp(r'[^\s]+'))],
          textInputAction: this.textInputAction,
          placeholder: help,
        ));
  }
}
