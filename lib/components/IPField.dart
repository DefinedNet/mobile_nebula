import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:mobile_nebula/components/SpecialTextField.dart';

import '../services/utils.dart';

class IPField extends StatelessWidget {
  final String help;
  final bool ipOnly;
  final bool autoFocus;
  final FocusNode? focusNode;
  final FocusNode? nextFocusNode;
  final ValueChanged<String>? onChanged;
  final EdgeInsetsGeometry textPadding;
  final TextInputAction? textInputAction;
  final controller;
  final textAlign;

  const IPField({
    super.key,
    this.ipOnly = false,
    this.help = "ip address",
    this.autoFocus = false,
    this.focusNode,
    this.nextFocusNode,
    this.onChanged,
    this.textPadding = const EdgeInsets.all(6.0),
    this.textInputAction,
    this.controller,
    this.textAlign = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    var textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    final double? ipWidth = ipOnly ? Utils.textSize("000000000000000", textStyle).width + 12 : null;

    return SizedBox(
      width: ipWidth,
      child: SpecialTextField(
        textAlign: textAlign,
        autofocus: autoFocus,
        focusNode: focusNode,
        nextFocusNode: nextFocusNode,
        controller: controller,
        onChanged: onChanged,
        maxLength: ipOnly ? 45 : null,
        maxLengthEnforcement: ipOnly ? MaxLengthEnforcement.enforced : MaxLengthEnforcement.none,
        inputFormatters:
            ipOnly
                ? [FilteringTextInputFormatter.allow(RegExp(r'[\d\.:a-fA-F]+'))]
                : [FilteringTextInputFormatter.allow(RegExp(r'[^\s]+'))],
        textInputAction: textInputAction,
        placeholder: help,
      ),
    );
  }
}
