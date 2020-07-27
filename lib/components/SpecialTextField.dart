import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

/// A normal TextField or CupertinoTextField that watches for copy, paste, cut, or select all keyboard actions
class SpecialTextField extends StatefulWidget {
  const SpecialTextField(
      {Key key,
      this.placeholder,
      this.suffix,
      this.controller,
      this.focusNode,
      this.nextFocusNode,
      this.autocorrect,
      this.minLines,
      this.maxLines,
      this.maxLength,
      this.maxLengthEnforced,
      this.style,
      this.keyboardType,
      this.textInputAction,
      this.textCapitalization,
      this.textAlign,
      this.autofocus,
      this.onChanged,
      this.expands,
      this.keyboardAppearance,
      this.textAlignVertical,
      this.inputFormatters})
      : super(key: key);

  final String placeholder;
  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode nextFocusNode;
  final bool autocorrect;
  final int minLines;
  final int maxLines;
  final int maxLength;
  final bool maxLengthEnforced;
  final Widget suffix;
  final TextStyle style;
  final TextInputType keyboardType;
  final Brightness keyboardAppearance;

  final TextInputAction textInputAction;
  final TextCapitalization textCapitalization;
  final TextAlign textAlign;
  final TextAlignVertical textAlignVertical;

  final bool autofocus;
  final ValueChanged<String> onChanged;
  final List<TextInputFormatter> inputFormatters;
  final bool expands;

  @override
  _SpecialTextFieldState createState() => _SpecialTextFieldState();
}

class _SpecialTextFieldState extends State<SpecialTextField> {
  FocusNode _focusNode = FocusNode();
  List<TextInputFormatter> formatters;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    formatters = widget.inputFormatters;
    if (formatters == null || formatters.length == 0) {
      formatters = [WhitelistingTextInputFormatter(RegExp(r'[^\t]'))];
    }

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
        focusNode: _focusNode,
        onKey: _onKey,
        child: PlatformTextField(
            autocorrect: widget.autocorrect,
            minLines: widget.minLines,
            maxLines: widget.maxLines,
            maxLength: widget.maxLength,
            maxLengthEnforced: widget.maxLengthEnforced,
            keyboardType: widget.keyboardType,
            keyboardAppearance: widget.keyboardAppearance,
            textInputAction: widget.textInputAction,
            textCapitalization: widget.textCapitalization,
            textAlign: widget.textAlign,
            textAlignVertical: widget.textAlignVertical,
            autofocus: widget.autofocus,
            focusNode: widget.focusNode,
            onChanged: widget.onChanged,
            onSubmitted: (_) {
              if (widget.nextFocusNode != null) {
                FocusScope.of(context).requestFocus(widget.nextFocusNode);
              }
            },
            expands: widget.expands,
            inputFormatters: formatters,
            android: (_) => MaterialTextFieldData(
                decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    hintText: widget.placeholder,
                    counterText: '',
                    suffix: widget.suffix)),
            ios: (_) => CupertinoTextFieldData(
                decoration: BoxDecoration(),
                padding: EdgeInsets.zero,
                placeholder: widget.placeholder,
                suffix: widget.suffix),
            style: widget.style,
            controller: widget.controller));
  }

  _onKey(RawKeyEvent event) {
    // We don't care about key up events
    if (event is RawKeyUpEvent) {
      return;
    }

    if (event.logicalKey == LogicalKeyboardKey.tab) {
      // Handle tab to the next node
      if (widget.nextFocusNode != null) {
        FocusScope.of(context).requestFocus(widget.nextFocusNode);
      }
      return;
    }

    // Handle special keyboard events with control key
    if (event.data.isControlPressed) {
      // Handle paste
      if (event.logicalKey == LogicalKeyboardKey.keyV) {
        Clipboard.getData("text/plain").then((data) {
          // Adjust our clipboard entry to confirm with the leftover space if we have maxLength
          var text = data.text;
          if (widget.maxLength != null && widget.maxLength > 0) {
            var leftover = widget.maxLength - widget.controller.text.length;
            if (leftover < data.text.length) {
              text = text.substring(0, leftover);
            }
          }

          // If maxLength took us to 0 then bail
          if (text.length == 0) {
            return;
          }

          var end = widget.controller.selection.end;
          var start = widget.controller.selection.start;

          // Insert our paste buffer into the selection, which can be 0 selected text (normal caret)
          widget.controller.text = widget.controller.selection.textBefore(widget.controller.text) +
              text +
              widget.controller.selection.textAfter(widget.controller.text);

          // Adjust our caret to be at the end of the pasted contents, need to take into account the size of the selection
          // We may want runes instead of
          end += text.length - (end - start);
          widget.controller.selection = TextSelection(baseOffset: end, extentOffset: end);
        });

        return;
      }

      // Handle select all
      if (event.logicalKey == LogicalKeyboardKey.keyA) {
        widget.controller.selection = TextSelection(baseOffset: 0, extentOffset: widget.controller.text.length);
        return;
      }

      // Handle copy
      if (event.logicalKey == LogicalKeyboardKey.keyC) {
        Clipboard.setData(ClipboardData(text: widget.controller.selection.textInside(widget.controller.text)));
        return;
      }

      // Handle cut
      if (event.logicalKey == LogicalKeyboardKey.keyX) {
        Clipboard.setData(ClipboardData(text: widget.controller.selection.textInside(widget.controller.text)));

        var start = widget.controller.selection.start;
        widget.controller.text = widget.controller.selection.textBefore(widget.controller.text) +
            widget.controller.selection.textAfter(widget.controller.text);
        widget.controller.selection = TextSelection(baseOffset: start, extentOffset: start);
        return;
      }
    }
  }
}
