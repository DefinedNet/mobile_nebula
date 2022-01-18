import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_nebula/components/SpecialTextField.dart';
//TODO: reset doesn't update the ui but clears the field

class PlatformTextFormField extends FormField<String> {
  //TODO: autovalidate, enabled?
  PlatformTextFormField(
      {Key key,
      widgetKey,
      this.controller,
      focusNode,
      nextFocusNode,
      TextInputType keyboardType,
      textInputAction,
      List<TextInputFormatter> inputFormatters,
      textAlign,
      autofocus,
      maxLines = 1,
      maxLength,
      maxLengthEnforcement,
      onChanged,
      keyboardAppearance,
      minLines,
      expands,
      suffix,
      textAlignVertical,
      String initialValue,
      String placeholder,
      FormFieldValidator<String> validator,
      ValueChanged<String> onSaved})
      : super(
            key: key,
            initialValue: controller != null ? controller.text : (initialValue ?? ''),
            onSaved: onSaved,
            validator: (str) {
              if (validator != null) {
                return validator(str);
              }

              return null;
            },
            builder: (FormFieldState<String> field) {
              final _PlatformTextFormFieldState state = field;

              void onChangedHandler(String value) {
                if (onChanged != null) {
                  onChanged(value);
                }
                field.didChange(value);
              }

              return Column(crossAxisAlignment: CrossAxisAlignment.end, children: <Widget>[
                SpecialTextField(
                    key: widgetKey,
                    controller: state._effectiveController,
                    focusNode: focusNode,
                    nextFocusNode: nextFocusNode,
                    keyboardType: keyboardType,
                    textInputAction: textInputAction,
                    textAlign: textAlign,
                    autofocus: autofocus,
                    maxLines: maxLines,
                    maxLength: maxLength,
                    maxLengthEnforcement: maxLengthEnforcement,
                    onChanged: onChangedHandler,
                    keyboardAppearance: keyboardAppearance,
                    minLines: minLines,
                    expands: expands,
                    textAlignVertical: textAlignVertical,
                    placeholder: placeholder,
                    inputFormatters: inputFormatters,
                    suffix: suffix),
                field.hasError
                    ? Text(
                        field.errorText,
                        style: TextStyle(color: CupertinoColors.systemRed.resolveFrom(field.context), fontSize: 13),
                        textAlign: textAlign,
                      )
                    : Container(height: 0)
              ]);
            });

  final TextEditingController controller;

  @override
  _PlatformTextFormFieldState createState() => _PlatformTextFormFieldState();
}

class _PlatformTextFormFieldState extends FormFieldState<String> {
  TextEditingController _controller;

  TextEditingController get _effectiveController => widget.controller ?? _controller;

  @override
  PlatformTextFormField get widget => super.widget;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _controller = TextEditingController(text: widget.initialValue);
    } else {
      widget.controller.addListener(_handleControllerChanged);
    }
  }

  @override
  void didUpdateWidget(PlatformTextFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChanged);
      widget.controller?.addListener(_handleControllerChanged);

      if (oldWidget.controller != null && widget.controller == null)
        _controller = TextEditingController.fromValue(oldWidget.controller.value);
      if (widget.controller != null) {
        setValue(widget.controller.text);
        if (oldWidget.controller == null) _controller = null;
      }
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleControllerChanged);
    super.dispose();
  }

  @override
  void reset() {
    super.reset();
    setState(() {
      _effectiveController.text = widget.initialValue;
    });
  }

  void _handleControllerChanged() {
    // Suppress changes that originated from within this class.
    //
    // In the case where a controller has been passed in to this widget, we
    // register this change listener. In these cases, we'll also receive change
    // notifications for changes originating from within this class -- for
    // example, the reset() method. In such cases, the FormField value will
    // already have been set.
    if (_effectiveController.text != value) didChange(_effectiveController.text);
  }
}
