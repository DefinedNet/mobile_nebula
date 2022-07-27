import 'package:flutter/cupertino.dart';
import 'package:mobile_nebula/validators/dnsValidator.dart';
import 'package:mobile_nebula/validators/ipValidator.dart';

import 'IPField.dart';

//TODO: reset doesn't update the ui but clears the field

class IPFormField extends FormField<String> {
  //TODO: validator, auto-validate, enabled?
  IPFormField({
    Key key,
    ipOnly = false,
    enableIPV6 = false,
    help = "ip address",
    autoFocus = false,
    focusNode,
    nextFocusNode,
    ValueChanged<String> onChanged,
    FormFieldSetter<String> onSaved,
    textPadding = const EdgeInsets.all(6.0),
    textInputAction,
    initialValue,
    this.controller,
    crossAxisAlignment = CrossAxisAlignment.center,
    textAlign = TextAlign.center,
  }) : super(
            key: key,
            initialValue: initialValue,
            onSaved: onSaved,
            validator: (ip) {
              if (ip == null || ip == "") {
                return "Please fill out this field";
              }

              if (!ipValidator(ip, enableIPV6) || (!ipOnly && !dnsValidator(ip))) {
                print(ip);
                return ipOnly ? 'Please enter a valid ip address' : 'Please enter a valid ip address or dns name';
              }

              return null;
            },
            builder: (FormFieldState<String> field) {
              final _IPFormField state = field;

              void onChangedHandler(String value) {
                if (onChanged != null) {
                  onChanged(value);
                }
                field.didChange(value);
              }

              return Column(crossAxisAlignment: crossAxisAlignment, children: <Widget>[
                IPField(
                    ipOnly: ipOnly,
                    help: help,
                    autoFocus: autoFocus,
                    focusNode: focusNode,
                    nextFocusNode: nextFocusNode,
                    onChanged: onChangedHandler,
                    textPadding: textPadding,
                    textInputAction: textInputAction,
                    controller: state._effectiveController,
                    textAlign: textAlign),
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
  _IPFormField createState() => _IPFormField();
}

class _IPFormField extends FormFieldState<String> {
  TextEditingController _controller;

  TextEditingController get _effectiveController => widget.controller ?? _controller;

  @override
  IPFormField get widget => super.widget;

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
  void didUpdateWidget(IPFormField oldWidget) {
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
