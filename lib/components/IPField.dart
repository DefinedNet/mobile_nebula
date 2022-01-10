import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
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
          maxLengthEnforcement: ipOnly ? MaxLengthEnforcement.enforced : MaxLengthEnforcement.none,
          inputFormatters: ipOnly ? [IPTextInputFormatter()] : [FilteringTextInputFormatter.allow(RegExp(r'[^\s]+'))],
          textInputAction: this.textInputAction,
          placeholder: help,
        ));
  }
}

class IPTextInputFormatter extends TextInputFormatter {
  final Pattern whitelistedPattern = RegExp(r'[\d\.,]+');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return _selectionAwareTextManipulation(
      newValue,
      (String substring) {
        return whitelistedPattern
            .allMatches(substring)
            .map<String>((Match match) => match.group(0))
            .join()
            .replaceAll(RegExp(r','), '.');
      },
    );
  }
}

TextEditingValue _selectionAwareTextManipulation(
  TextEditingValue value,
  String substringManipulation(String substring),
) {
  final int selectionStartIndex = value.selection.start;
  final int selectionEndIndex = value.selection.end;
  String manipulatedText;
  TextSelection manipulatedSelection;
  if (selectionStartIndex < 0 || selectionEndIndex < 0) {
    manipulatedText = substringManipulation(value.text);
  } else {
    final String beforeSelection = substringManipulation(value.text.substring(0, selectionStartIndex));
    final String inSelection = substringManipulation(value.text.substring(selectionStartIndex, selectionEndIndex));
    final String afterSelection = substringManipulation(value.text.substring(selectionEndIndex));
    manipulatedText = beforeSelection + inSelection + afterSelection;
    if (value.selection.baseOffset > value.selection.extentOffset) {
      manipulatedSelection = value.selection.copyWith(
        baseOffset: beforeSelection.length + inSelection.length,
        extentOffset: beforeSelection.length,
      );
    } else {
      manipulatedSelection = value.selection.copyWith(
        baseOffset: beforeSelection.length,
        extentOffset: beforeSelection.length + inSelection.length,
      );
    }
  }
  return TextEditingValue(
    text: manipulatedText,
    selection: manipulatedSelection ?? const TextSelection.collapsed(offset: -1),
    composing: manipulatedText == value.text ? value.composing : TextRange.empty,
  );
}
