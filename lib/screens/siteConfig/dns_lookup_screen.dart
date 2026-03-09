import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_nebula/components/config/config_checkbox_item.dart';
import 'package:mobile_nebula/components/config/config_section.dart';
import 'package:mobile_nebula/components/form_page.dart';

class DnsLookupScreen extends StatefulWidget {
  const DnsLookupScreen({super.key, required this.staticMapNetwork, required this.onSave});

  final String staticMapNetwork;
  final ValueChanged<String> onSave;

  @override
  DnsLookupScreenState createState() => DnsLookupScreenState();
}

class DnsLookupScreenState extends State<DnsLookupScreen> {
  late String staticMapNetwork;
  bool changed = false;

  @override
  void initState() {
    staticMapNetwork = widget.staticMapNetwork;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'DNS Lookup Mode',
      changed: changed,
      onSave: () {
        Navigator.pop(context);
        widget.onSave(staticMapNetwork);
      },
      child: Column(
        children: <Widget>[
          ConfigSection(
            children: [_buildEntry('ip4', 'IPv4 only'), _buildEntry('ip6', 'IPv6 only'), _buildEntry('ip', 'Both')],
          ),
        ],
      ),
    );
  }

  Widget _buildEntry(String value, String label) {
    return ConfigCheckboxItem(
      label: Text(label),
      labelWidth: 150,
      checked: staticMapNetwork == value,
      onChanged: () {
        setState(() {
          changed = true;
          staticMapNetwork = value;
        });
      },
    );
  }
}
