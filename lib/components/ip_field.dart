import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:mobile_nebula/components/special_text_field.dart';

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
  final TextEditingController? controller;
  final TextAlign textAlign;
  final bool autoSize;
  final bool enabled;

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
    this.autoSize = true,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    var textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    final double? ipWidth = ipOnly ? Utils.textSize("000000000000000", textStyle).width + 12 : null;

    final child = SpecialTextField(
      textAlign: textAlign,
      autofocus: autoFocus,
      focusNode: focusNode,
      nextFocusNode: nextFocusNode,
      controller: controller,
      onChanged: onChanged,
      maxLength: ipOnly ? 45 : null,
      maxLengthEnforcement: ipOnly ? MaxLengthEnforcement.enforced : MaxLengthEnforcement.none,
      inputFormatters: ipOnly
          ? [FilteringTextInputFormatter.allow(RegExp(r'[\d\.:a-fA-F]+'))]
          : [FilteringTextInputFormatter.allow(RegExp(r'[^\s]+'))],
      textInputAction: textInputAction,
      placeholder: help,
      enabled: enabled,
    );

    if (autoSize) {
      return SizedBox(width: ipWidth, child: child);
    } else {
      return child;
    }
  }
}
