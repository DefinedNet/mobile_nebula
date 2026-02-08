import 'package:flutter/cupertino.dart';
import 'package:mobile_nebula/components/cidr_form_field.dart';
import 'package:mobile_nebula/components/config/config_item.dart';
import 'package:mobile_nebula/components/config/config_section.dart';
import 'package:mobile_nebula/components/danger_button.dart';
import 'package:mobile_nebula/components/form_page.dart';
import 'package:mobile_nebula/components/ip_form_field.dart';
import 'package:mobile_nebula/models/cidr.dart';
import 'package:mobile_nebula/models/unsafe_route.dart';
import 'package:mobile_nebula/services/utils.dart';

class UnsafeRouteScreen extends StatefulWidget {
  const UnsafeRouteScreen({super.key, required this.route, required this.onSave, this.onDelete});

  final UnsafeRoute route;
  final ValueChanged<UnsafeRoute> onSave;
  final Function? onDelete;

  @override
  UnsafeRouteScreenState createState() => UnsafeRouteScreenState();
}

class UnsafeRouteScreenState extends State<UnsafeRouteScreen> {
  late UnsafeRoute route;
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
    var routeCIDR = route.route == null ? CIDR() : CIDR.fromString(route.route!);

    return FormPage(
      title: widget.onDelete == null ? 'New Unsafe Route' : 'Edit Unsafe Route',
      changed: changed,
      onSave: _onSave,
      child: Column(
        children: [
          ConfigSection(
            children: <Widget>[
              ConfigItem(
                label: Text('Route'),
                content: CIDRFormField(
                  initialValue: routeCIDR,
                  textInputAction: TextInputAction.next,
                  focusNode: routeFocus,
                  nextFocusNode: viaFocus,
                  onSaved: (v) {
                    route.route = v.toString();
                  },
                ),
              ),
              ConfigItem(
                label: Text('Via'),
                content: IPFormField(
                  initialValue: route.via ?? '',
                  ipOnly: true,
                  help: 'nebula ip',
                  textAlign: TextAlign.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  textInputAction: TextInputAction.next,
                  focusNode: viaFocus,
                  nextFocusNode: mtuFocus,
                  onSaved: (v) {
                    if (v != null) {
                      route.via = v;
                    }
                  },
                ),
              ),
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
            ],
          ),
          widget.onDelete != null
              ? Padding(
                padding: EdgeInsets.only(top: 50, bottom: 10, left: 10, right: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: DangerButton(
                    child: Text('Delete'),
                    onPressed:
                        () => Utils.confirmDelete(context, 'Delete unsafe route?', () {
                          Navigator.of(context).pop();
                          widget.onDelete!();
                        }),
                  ),
                ),
              )
              : Container(),
        ],
      ),
    );
  }

  _onSave() {
    Navigator.pop(context);
    widget.onSave(route);
  }
}
