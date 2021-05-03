import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_nebula/components/SpecialTextField.dart';
import 'package:mobile_nebula/models/CIDR.dart';
import '../services/utils.dart';
import 'IPField.dart';

//TODO: Support initialValue
class CIDRField extends StatefulWidget {
  const CIDRField({
    Key key,
    this.ipHelp = "ip address",
    this.autoFocus = false,
    this.focusNode,
    this.nextFocusNode,
    this.onChanged,
    this.textInputAction,
    this.ipController,
    this.bitsController,
  }) : super(key: key);

  final String ipHelp;
  final bool autoFocus;
  final FocusNode focusNode;
  final FocusNode nextFocusNode;
  final ValueChanged<CIDR> onChanged;
  final TextInputAction textInputAction;
  final TextEditingController ipController;
  final TextEditingController bitsController;

  @override
  _CIDRFieldState createState() => _CIDRFieldState();
}

//TODO: if the keyboard is open on the port field and you switch to dark mode, it crashes
//TODO: maybe add in a next/done step for numeric keyboards
//TODO: rig up focus node and next node
//TODO: rig up textInputAction
class _CIDRFieldState extends State<CIDRField> {
  final bitsFocus = FocusNode();
  final cidr = CIDR();

  @override
  void initState() {
    //TODO: this won't track external controller changes appropriately
    cidr.ip = widget.ipController?.text ?? "";
    cidr.bits = int.tryParse(widget.bitsController?.text ?? "");
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var textStyle = CupertinoTheme.of(context).textTheme.textStyle;

    return Container(
        child: Row(children: <Widget>[
      Expanded(
          child: Padding(
              padding: EdgeInsets.fromLTRB(6, 6, 2, 6),
              child: IPField(
                help: widget.ipHelp,
                ipOnly: true,
                textPadding: EdgeInsets.all(0),
                textInputAction: TextInputAction.next,
                textAlign: TextAlign.end,
                focusNode: widget.focusNode,
                nextFocusNode: bitsFocus,
                onChanged: (val) {
                  cidr.ip = val;
                  widget.onChanged(cidr);
                },
                controller: widget.ipController,
              ))),
      Text("/"),
      Container(
          width: Utils.textSize("bits", textStyle).width + 12,
          padding: EdgeInsets.fromLTRB(2, 6, 6, 6),
          child: SpecialTextField(
            keyboardType: TextInputType.number,
            focusNode: bitsFocus,
            nextFocusNode: widget.nextFocusNode,
            controller: widget.bitsController,
            onChanged: (val) {
              cidr.bits = int.tryParse(val ?? "");
              widget.onChanged(cidr);
            },
            maxLength: 2,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: widget.textInputAction ?? TextInputAction.done,
            placeholder: 'bits',
          ))
    ]));
  }

  @override
  void dispose() {
    bitsFocus.dispose();
    super.dispose();
  }
}
