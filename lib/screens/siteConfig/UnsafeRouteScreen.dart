import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:mobile_nebula/components/CIDRFormField.dart';
import 'package:mobile_nebula/components/FormPage.dart';
import 'package:mobile_nebula/components/IPFormField.dart';
import 'package:mobile_nebula/components/PlatformTextFormField.dart';
import 'package:mobile_nebula/components/config/ConfigItem.dart';
import 'package:mobile_nebula/components/config/ConfigSection.dart';
import 'package:mobile_nebula/models/CIDR.dart';
import 'package:mobile_nebula/models/UnsafeRoute.dart';
import 'package:mobile_nebula/services/utils.dart';
import 'package:mobile_nebula/validators/mtuValidator.dart';

class UnsafeRouteScreen extends StatefulWidget {
  const UnsafeRouteScreen({Key key, this.route, this.onDelete, @required this.onSave}) : super(key: key);

  final UnsafeRoute route;
  final ValueChanged<UnsafeRoute> onSave;
  final Function onDelete;

  @override
  _UnsafeRouteScreenState createState() => _UnsafeRouteScreenState();
}

class _UnsafeRouteScreenState extends State<UnsafeRouteScreen> {
  UnsafeRoute route;
  bool changed = false;

  FocusNode routeFocus = FocusNode();
  FocusNode viaFocus = FocusNode();
  FocusNode mtuFocus = FocusNode();

  @override
  void initState() {
    route = widget.route;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var routeCIDR = route?.route == null ? CIDR() : CIDR.fromString(route?.route);

    return FormPage(
        title: widget.onDelete == null ? 'New Unsafe Route' : 'Edit Unsafe Route',
        changed: changed,
        onSave: _onSave,
        child: Column(children: [
          ConfigSection(children: <Widget>[
            ConfigItem(
                label: Text('Route'),
                content: CIDRFormField(
                    initialValue: routeCIDR,
                    textInputAction: TextInputAction.next,
                    focusNode: routeFocus,
                    nextFocusNode: viaFocus,
                    onSaved: (v) {
                      route.route = v.toString();
                    })),
            ConfigItem(
                label: Text('Via'),
                content: IPFormField(
                    initialValue: route?.via ?? "",
                    ipOnly: true,
                    help: 'nebula ip',
                    textAlign: TextAlign.end,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    textInputAction: TextInputAction.next,
                    focusNode: viaFocus,
                    nextFocusNode: mtuFocus,
                    onSaved: (v) {
                      route.via = v;
                    })),
//TODO: Android doesn't appear to support route based MTU, figure this out
//            ConfigItem(
//                label: Text('MTU'),
//                content: PlatformTextFormField(
//                    placeholder: "",
//                    validator: mtuValidator(false),
//                    keyboardType: TextInputType.number,
//                    inputFormatters: [WhitelistingTextInputFormatter.digitsOnly],
//                    initialValue: route?.mtu.toString(),
//                    textAlign: TextAlign.end,
//                    textInputAction: TextInputAction.done,
//                    focusNode: mtuFocus,
//                    onSaved: (v) {
//                      route.mtu = int.tryParse(v);
//                    })),
          ]),
          widget.onDelete != null
              ? Padding(
                  padding: EdgeInsets.only(top: 50, bottom: 10, left: 10, right: 10),
                  child: SizedBox(
                      width: double.infinity,
                      child: PlatformButton(
                        child: Text('Delete'),
                        color: CupertinoColors.systemRed.resolveFrom(context),
                        onPressed: () => Utils.confirmDelete(context, 'Delete unsafe route?', () {
                          Navigator.of(context).pop();
                          widget.onDelete();
                        }),
                      )))
              : Container()
        ]));
  }

  _onSave() {
    Navigator.pop(context);
    if (widget.onSave != null) {
      widget.onSave(route);
    }
  }
}
