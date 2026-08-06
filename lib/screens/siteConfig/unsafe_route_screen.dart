import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_nebula/components/danger_button.dart';
import 'package:mobile_nebula/components/cidr_form_field.dart';
import 'package:mobile_nebula/components/config/config_button_item.dart';
import 'package:mobile_nebula/components/config/config_item.dart';
import 'package:mobile_nebula/components/config/config_section.dart';
import 'package:mobile_nebula/components/form_page.dart';
import 'package:mobile_nebula/models/cidr.dart';
import 'package:mobile_nebula/models/unsafe_route.dart';
import 'package:mobile_nebula/services/utils.dart';
import 'package:mobile_nebula/validators/ip_validator.dart';

class _GatewayControllers {
  final TextEditingController ip;
  final TextEditingController weight;

  _GatewayControllers({String gateway = '', int weight = 1})
    : ip = TextEditingController(text: gateway),
      weight = TextEditingController(text: weight.toString());

  void dispose() {
    ip.dispose();
    weight.dispose();
  }
}

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
  late List<_GatewayControllers> _gatewayControllers;

  FocusNode routeFocus = FocusNode();

  @override
  void initState() {
    route = UnsafeRoute(route: widget.route.route, via: []);
    final initial = widget.route.via.isNotEmpty ? widget.route.via : [Gateway(gateway: '', weight: 1)];
    _gatewayControllers = initial.map((g) => _GatewayControllers(gateway: g.gateway, weight: g.weight)).toList();
    super.initState();
  }

  @override
  void dispose() {
    routeFocus.dispose();
    for (final c in _gatewayControllers) {
      c.dispose();
    }
    super.dispose();
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
                  onSaved: (v) {
                    route.route = v.toString();
                  },
                ),
              ),
            ],
          ),
          ConfigSection(
            label: 'Gateways',
            children: [
              ..._buildGatewayRows(),
              ConfigButtonItem(
                content: Text('Add Gateway'),
                onPressed: () {
                  setState(() {
                    changed = true;
                    _gatewayControllers.add(_GatewayControllers());
                  });
                },
              ),
            ],
          ),
          widget.onDelete != null
              ? Padding(
                  padding: EdgeInsets.only(top: 50, bottom: 10, left: 10, right: 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: DangerButton(
                      child: Text('Delete'),
                      onPressed: () => Utils.confirmDelete(context, 'Delete unsafe route?', () {
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

  List<Widget> _buildGatewayRows() {
    final rows = <Widget>[];
    for (int i = 0; i < _gatewayControllers.length; i++) {
      rows.add(_buildGatewayRow(i));
    }
    return rows;
  }

  Widget _buildGatewayRow(int index) {
    final ctrl = _gatewayControllers[index];
    final canRemove = _gatewayControllers.length > 1;

    return ConfigItem(
      label: Text('Gateway ${index + 1}'),
      labelWidth: 110,
      crossAxisAlignment: CrossAxisAlignment.start,
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 15),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: ctrl.ip,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.end,
                  decoration: InputDecoration(hintText: 'nebula ip', isDense: true, border: InputBorder.none),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    var (valid, _) = ipValidator(v);
                    if (!valid) return 'Invalid IP';
                    return null;
                  },
                ),
              ),
              if (canRemove)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      changed = true;
                      _gatewayControllers.removeAt(index).dispose();
                    });
                  },
                  child: Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                  ),
                ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Weight: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
              SizedBox(
                width: 48,
                child: TextFormField(
                  controller: ctrl.weight,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(isDense: true, border: InputBorder.none),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n < 1) return '≥1';
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onSave() {
    Navigator.pop(context);
    route.via = _gatewayControllers
        .map((c) => Gateway(gateway: c.ip.text, weight: int.tryParse(c.weight.text) ?? 1))
        .toList();
    widget.onSave(route);
  }
}
