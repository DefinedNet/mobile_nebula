import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:mobile_nebula/components/SpecialTextField.dart';
import 'package:mobile_nebula/models/IPAndPort.dart';
import '../services/utils.dart';
import 'IPField.dart';

//TODO: Support initialValue
class IPAndPortField extends StatefulWidget {
  const IPAndPortField({
    Key? key,
    this.ipOnly = false,
    this.ipHelp = "ip address",
    this.autoFocus = false,
    this.focusNode,
    this.nextFocusNode,
    required this.onChanged,
    this.textInputAction,
    this.noBorder = false,
    this.ipTextAlign,
    this.ipController,
    this.portController,
  }) : super(key: key);

  final String ipHelp;
  final bool ipOnly;
  final bool autoFocus;
  final FocusNode? focusNode;
  final FocusNode? nextFocusNode;
  final ValueChanged<IPAndPort> onChanged;
  final TextInputAction? textInputAction;
  final bool noBorder;
  final TextAlign? ipTextAlign;
  final TextEditingController? ipController;
  final TextEditingController? portController;

  @override
  _IPAndPortFieldState createState() => _IPAndPortFieldState();
}

//TODO: if the keyboard is open on the port field and you switch to dark mode, it crashes
//TODO: maybe add in a next/done step for numeric keyboards
//TODO: rig up focus node and next node
//TODO: rig up textInputAction
class _IPAndPortFieldState extends State<IPAndPortField> {
  final _portFocus = FocusNode();
  final _ipAndPort = IPAndPort();

  @override
  void initState() {
    //TODO: this won't track external controller changes appropriately
    _ipAndPort.ip = widget.ipController?.text ?? "";
    _ipAndPort.port = int.tryParse(widget.portController?.text ?? "");
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var textStyle = CupertinoTheme.of(context).textTheme.textStyle;

    return Container(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(6, 6, 2, 6),
              child: IPField(
                help: widget.ipHelp,
                ipOnly: widget.ipOnly,
                nextFocusNode: _portFocus,
                textPadding: EdgeInsets.all(0),
                textInputAction: TextInputAction.next,
                focusNode: widget.focusNode,
                onChanged: (val) {
                  _ipAndPort.ip = val;
                  widget.onChanged(_ipAndPort);
                },
                textAlign: widget.ipTextAlign,
                controller: widget.ipController,
              ),
            ),
          ),
          Text(":"),
          Container(
            width: Utils.textSize("00000", textStyle).width + 12,
            padding: EdgeInsets.fromLTRB(2, 6, 6, 6),
            child: SpecialTextField(
              keyboardType: TextInputType.number,
              focusNode: _portFocus,
              nextFocusNode: widget.nextFocusNode,
              controller: widget.portController,
              onChanged: (val) {
                _ipAndPort.port = int.tryParse(val);
                widget.onChanged(_ipAndPort);
              },
              maxLength: 5,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.done,
              placeholder: 'port',
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _portFocus.dispose();
    super.dispose();
  }
}
