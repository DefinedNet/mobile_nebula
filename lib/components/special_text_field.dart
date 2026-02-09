import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

/// A normal TextField or CupertinoTextField that looks the same on all platforms
class SpecialTextField extends StatefulWidget {
  const SpecialTextField({
    super.key,
    this.placeholder,
    this.suffix,
    this.controller,
    this.focusNode,
    this.nextFocusNode,
    this.autocorrect,
    this.minLines,
    this.maxLines,
    this.maxLength,
    this.maxLengthEnforcement,
    this.style,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization,
    this.textAlign,
    this.autofocus,
    this.onChanged,
    this.enabled,
    this.expands,
    this.keyboardAppearance,
    this.textAlignVertical,
    this.inputFormatters,
  });

  final String? placeholder;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final FocusNode? nextFocusNode;
  final bool? autocorrect;
  final int? minLines;
  final int? maxLines;
  final int? maxLength;
  final MaxLengthEnforcement? maxLengthEnforcement;
  final Widget? suffix;
  final TextStyle? style;
  final TextInputType? keyboardType;
  final Brightness? keyboardAppearance;

  final TextInputAction? textInputAction;
  final TextCapitalization? textCapitalization;
  final TextAlign? textAlign;
  final TextAlignVertical? textAlignVertical;

  final bool? autofocus;
  final ValueChanged<String>? onChanged;
  final bool? enabled;
  final List<TextInputFormatter>? inputFormatters;
  final bool? expands;

  @override
  SpecialTextFieldState createState() => SpecialTextFieldState();
}

class SpecialTextFieldState extends State<SpecialTextField> {
  List<TextInputFormatter> formatters = [];

  @override
  void initState() {
    if (widget.inputFormatters == null || formatters.isEmpty) {
      formatters = [FilteringTextInputFormatter.allow(RegExp(r'[^\t]'))];
    } else {
      formatters = widget.inputFormatters!;
    }

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return PlatformTextField(
      autocorrect: widget.autocorrect,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      maxLengthEnforcement: widget.maxLengthEnforcement,
      keyboardType: widget.keyboardType,
      keyboardAppearance: widget.keyboardAppearance,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      textAlign: widget.textAlign,
      textAlignVertical: widget.textAlignVertical,
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      onChanged: widget.onChanged,
      enabled: widget.enabled ?? true,
      onSubmitted: (_) {
        if (widget.nextFocusNode != null) {
          FocusScope.of(context).requestFocus(widget.nextFocusNode);
        }
      },
      expands: widget.expands,
      inputFormatters: formatters,
      material:
          (_, __) => MaterialTextFieldData(
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
              hintText: widget.placeholder,
              counterText: '',
              suffix: widget.suffix,
            ),
          ),
      cupertino:
          (_, __) => CupertinoTextFieldData(
            decoration: BoxDecoration(),
            padding: EdgeInsets.zero,
            placeholder: widget.placeholder,
            suffix: widget.suffix,
          ),
      style: widget.style,
      controller: widget.controller,
    );
  }
}
