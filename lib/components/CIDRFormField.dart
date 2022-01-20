import 'package:flutter/cupertino.dart';
import 'package:mobile_nebula/components/CIDRField.dart';
import 'package:mobile_nebula/models/CIDR.dart';
import 'package:mobile_nebula/validators/ipValidator.dart';

class CIDRFormField extends FormField<CIDR> {
  //TODO: onSaved, validator, auto-validate, enabled?
  CIDRFormField({
    Key key,
    autoFocus = false,
    enableIPV6 = false,
    focusNode,
    nextFocusNode,
    ValueChanged<CIDR> onChanged,
    FormFieldSetter<CIDR> onSaved,
    textInputAction,
    CIDR initialValue,
    this.ipController,
    this.bitsController,
  }) : super(
            key: key,
            initialValue: initialValue,
            onSaved: onSaved,
            validator: (cidr) {
              if (cidr == null) {
                return "Please fill out this field";
              }

              if (!ipValidator(cidr.ip, enableIPV6)) {
                return 'Please enter a valid ip address';
              }

              if (cidr.bits == null || cidr.bits > 32 || cidr.bits < 0) {
                return "Please enter a valid number of bits";
              }

              return null;
            },
            builder: (FormFieldState<CIDR> field) {
              final _CIDRFormField state = field;

              void onChangedHandler(CIDR value) {
                if (onChanged != null) {
                  onChanged(value);
                }
                field.didChange(value);
              }

              return Column(crossAxisAlignment: CrossAxisAlignment.end, children: <Widget>[
                CIDRField(
                  autoFocus: autoFocus,
                  focusNode: focusNode,
                  nextFocusNode: nextFocusNode,
                  onChanged: onChangedHandler,
                  textInputAction: textInputAction,
                  ipController: state._effectiveIPController,
                  bitsController: state._effectiveBitsController,
                ),
                field.hasError
                    ? Text(field.errorText,
                        style: TextStyle(color: CupertinoColors.systemRed.resolveFrom(field.context), fontSize: 13),
                        textAlign: TextAlign.end)
                    : Container(height: 0)
              ]);
            });

  final TextEditingController ipController;
  final TextEditingController bitsController;

  @override
  _CIDRFormField createState() => _CIDRFormField();
}

class _CIDRFormField extends FormFieldState<CIDR> {
  TextEditingController _ipController;
  TextEditingController _bitsController;

  TextEditingController get _effectiveIPController => widget.ipController ?? _ipController;
  TextEditingController get _effectiveBitsController => widget.bitsController ?? _bitsController;

  @override
  CIDRFormField get widget => super.widget;

  @override
  void initState() {
    super.initState();
    if (widget.ipController == null) {
      _ipController = TextEditingController(text: widget.initialValue.ip);
    } else {
      widget.ipController.addListener(_handleControllerChanged);
    }

    if (widget.bitsController == null) {
      _bitsController = TextEditingController(text: widget.initialValue?.bits?.toString() ?? "");
    } else {
      widget.bitsController.addListener(_handleControllerChanged);
    }
  }

  @override
  void didUpdateWidget(CIDRFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    var update = CIDR(ip: widget.ipController?.text, bits: int.tryParse(widget.bitsController?.text ?? "") ?? null);
    bool shouldUpdate = false;

    if (widget.ipController != oldWidget.ipController) {
      oldWidget.ipController?.removeListener(_handleControllerChanged);
      widget.ipController?.addListener(_handleControllerChanged);

      if (oldWidget.ipController != null && widget.ipController == null) {
        _ipController = TextEditingController.fromValue(oldWidget.ipController.value);
      }

      if (widget.ipController != null) {
        shouldUpdate = true;
        update.ip = widget.ipController.text;
        if (oldWidget.ipController == null) _ipController = null;
      }
    }

    if (widget.bitsController != oldWidget.bitsController) {
      oldWidget.bitsController?.removeListener(_handleControllerChanged);
      widget.bitsController?.addListener(_handleControllerChanged);

      if (oldWidget.bitsController != null && widget.bitsController == null) {
        _bitsController = TextEditingController.fromValue(oldWidget.bitsController.value);
      }

      if (widget.bitsController != null) {
        shouldUpdate = true;
        update.bits = int.parse(widget.bitsController.text);
        if (oldWidget.bitsController == null) _bitsController = null;
      }
    }

    if (shouldUpdate) {
      setValue(update);
    }
  }

  @override
  void dispose() {
    widget.ipController?.removeListener(_handleControllerChanged);
    widget.bitsController?.removeListener(_handleControllerChanged);
    super.dispose();
  }

  @override
  void reset() {
    super.reset();
    setState(() {
      _effectiveIPController.text = widget.initialValue.ip;
      _effectiveBitsController.text = widget.initialValue.bits.toString();
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
    final effectiveBits = int.parse(_effectiveBitsController.text);
    if (_effectiveIPController.text != value.ip || effectiveBits != value.bits) {
      didChange(CIDR(ip: _effectiveIPController.text, bits: effectiveBits));
    }
  }
}
