import 'package:flutter/material.dart';
import 'package:mobile_nebula/components/cidr_form_field.dart';
import 'package:mobile_nebula/components/config/config_item.dart';
import 'package:mobile_nebula/components/config/config_section.dart';
import 'package:mobile_nebula/components/form_page.dart';
import 'package:mobile_nebula/models/cidr.dart';

class FirewallLocalCidrScreen extends StatefulWidget {
  const FirewallLocalCidrScreen({super.key, required this.initialValue, required this.onSave});

  final CIDR? initialValue;
  final ValueChanged<CIDR?> onSave;

  @override
  State<FirewallLocalCidrScreen> createState() => _FirewallLocalCidrScreenState();
}

class _FirewallLocalCidrScreenState extends State<FirewallLocalCidrScreen> {
  CIDR? _value;
  bool changed = false;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'Local CIDR',
      changed: changed,
      onSave: () {
        final result = (_value != null && _value!.ip.isEmpty && _value!.bits == 0) ? null : _value;
        widget.onSave(result);
        Navigator.pop(context);
      },
      child: ConfigSection(
        children: [
          ConfigItem(
            content: CIDRFormField(
              required: false,
              initialValue: _value,
              textInputAction: TextInputAction.done,
              onSaved: (v) {
                _value = (v != null && v.ip.isEmpty && v.bits == 0) ? null : v;
              },
            ),
          ),
        ],
      ),
    );
  }
}
