import 'package:flutter/cupertino.dart';
import 'package:mobile_nebula/models/IPAndPort.dart';
import 'package:mobile_nebula/validators/dnsValidator.dart';
import 'package:mobile_nebula/validators/ipValidator.dart';

import 'IPAndPortField.dart';

class IPAndPortFormField extends FormField<IPAndPort> {
  //TODO: onSaved, validator, auto-validate, enabled?
  IPAndPortFormField({
    Key? key,
    ipOnly = false,
    enableIPV6 = false,
    ipHelp = "ip address",
    autoFocus = false,
    focusNode,
    nextFocusNode,
    ValueChanged<IPAndPort>? onChanged,
    FormFieldSetter<IPAndPort>? onSaved,
    textInputAction,
    IPAndPort? initialValue,
    noBorder,
    ipTextAlign = TextAlign.center,
    this.ipController,
    this.portController,
  }) : super(
         key: key,
         initialValue: initialValue,
         onSaved: onSaved,
         validator: (ipAndPort) {
           if (ipAndPort == null) {
             return "Please fill out this field";
           }

           if (!ipValidator(ipAndPort.ip, enableIPV6) && (!ipOnly && !dnsValidator(ipAndPort.ip))) {
             return ipOnly ? 'Please enter a valid ip address' : 'Please enter a valid ip address or dns name';
           }

           if (ipAndPort.port == null || ipAndPort.port! > 65535 || ipAndPort.port! < 0) {
             return "Please enter a valid port";
           }

           return null;
         },
         builder: (FormFieldState<IPAndPort> field) {
           final _IPAndPortFormField state = field as _IPAndPortFormField;

           void onChangedHandler(IPAndPort value) {
             if (onChanged != null) {
               onChanged(value);
             }
             field.didChange(value);
           }

           return Column(
             children: <Widget>[
               IPAndPortField(
                 ipOnly: ipOnly,
                 ipHelp: ipHelp,
                 autoFocus: autoFocus,
                 focusNode: focusNode,
                 nextFocusNode: nextFocusNode,
                 onChanged: onChangedHandler,
                 textInputAction: textInputAction,
                 ipController: state._effectiveIPController,
                 portController: state._effectivePortController,
                 noBorder: noBorder,
                 ipTextAlign: ipTextAlign,
               ),
               field.hasError
                   ? Text(
                     field.errorText!,
                     style: TextStyle(color: CupertinoColors.systemRed.resolveFrom(field.context), fontSize: 13),
                   )
                   : Container(height: 0),
             ],
           );
         },
       );

  final TextEditingController? ipController;
  final TextEditingController? portController;

  @override
  _IPAndPortFormField createState() => _IPAndPortFormField();
}

class _IPAndPortFormField extends FormFieldState<IPAndPort> {
  TextEditingController? _ipController;
  TextEditingController? _portController;

  TextEditingController get _effectiveIPController => widget.ipController ?? _ipController!;
  TextEditingController get _effectivePortController => widget.portController ?? _portController!;

  @override
  IPAndPortFormField get widget => super.widget as IPAndPortFormField;

  @override
  void initState() {
    super.initState();
    if (widget.ipController == null) {
      _ipController = TextEditingController(text: widget.initialValue?.ip ?? "");
    } else {
      widget.ipController!.addListener(_handleControllerChanged);
    }

    if (widget.portController == null) {
      _portController = TextEditingController(text: widget.initialValue?.port?.toString() ?? "");
    } else {
      widget.portController!.addListener(_handleControllerChanged);
    }
  }

  @override
  void didUpdateWidget(IPAndPortFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    var update = IPAndPort(
      ip: widget.ipController?.text,
      port: int.tryParse(widget.portController?.text ?? "") ?? null,
    );
    bool shouldUpdate = false;

    if (widget.ipController != oldWidget.ipController) {
      oldWidget.ipController?.removeListener(_handleControllerChanged);
      widget.ipController?.addListener(_handleControllerChanged);

      if (oldWidget.ipController != null && widget.ipController == null) {
        _ipController = TextEditingController.fromValue(oldWidget.ipController!.value);
      }

      if (widget.ipController != null) {
        shouldUpdate = true;
        update.ip = widget.ipController!.text;
        if (oldWidget.ipController == null) _ipController = null;
      }
    }

    if (widget.portController != oldWidget.portController) {
      oldWidget.portController?.removeListener(_handleControllerChanged);
      widget.portController?.addListener(_handleControllerChanged);

      if (oldWidget.portController != null && widget.portController == null) {
        _portController = TextEditingController.fromValue(oldWidget.portController!.value);
      }

      if (widget.portController != null) {
        shouldUpdate = true;
        update.port = int.parse(widget.portController!.text);
        if (oldWidget.portController == null) _portController = null;
      }
    }

    if (shouldUpdate) {
      setValue(update);
    }
  }

  @override
  void dispose() {
    widget.ipController?.removeListener(_handleControllerChanged);
    widget.portController?.removeListener(_handleControllerChanged);
    super.dispose();
  }

  @override
  void reset() {
    super.reset();
    setState(() {
      _effectiveIPController.text = widget.initialValue?.ip ?? "";
      _effectivePortController.text = widget.initialValue?.port?.toString() ?? "";
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
    final effectivePort = int.parse(_effectivePortController.text);
    if (value == null) {
      return;
    }

    if (_effectiveIPController.text != value!.ip || effectivePort != value!.port) {
      didChange(IPAndPort(ip: _effectiveIPController.text, port: effectivePort));
    }
  }
}
