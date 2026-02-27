import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:mobile_nebula/components/config/config_button_item.dart';
import 'package:mobile_nebula/components/config/config_item.dart';
import 'package:mobile_nebula/components/config/config_section.dart';
import 'package:mobile_nebula/components/form_page.dart';
import 'package:mobile_nebula/components/ip_form_field.dart';

class _Resolver {
  final FocusNode focusNode;
  String address;

  _Resolver({required this.focusNode, required this.address});
}

class DnsResolversScreen extends StatefulWidget {
  DnsResolversScreen({super.key, dnsResolvers, required this.onSave}) : dnsResolvers = dnsResolvers ?? [];

  final List<String> dnsResolvers;
  final ValueChanged<List<String>>? onSave;

  @override
  DnsResolversScreenState createState() => DnsResolversScreenState();
}

class DnsResolversScreenState extends State<DnsResolversScreen> {
  late Map<Key, _Resolver> _dnsResolvers;
  bool changed = false;

  @override
  void initState() {
    _dnsResolvers = {};
    for (var address in widget.dnsResolvers) {
      _dnsResolvers[UniqueKey()] = _Resolver(focusNode: FocusNode(), address: address);
    }

    if (_dnsResolvers.isEmpty) {
      _addResolver();
    }

    // _addResolver() above sets us to changed, set it back to false since we are at the default state
    changed = false;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'DNS Resolvers',
      changed: changed,
      onSave: _onSave,
      child: Column(
        children: [
          ConfigSection(
            label:
                'List of dns resolvers to use for lookups.\nAny resolver that isn\'t in your networks or unsafe networks will be routed in plaintext.',
            children: _buildHosts(),
          ),
        ],
      ),
    );
  }

  void _onSave() {
    Navigator.pop(context);
    if (widget.onSave != null) {
      List<String> resolvers = [];
      _dnsResolvers.forEach((_, resolver) {
        final address = resolver.address.trim();
        if (address.isNotEmpty) {
          resolvers.add(address);
        }
      });

      widget.onSave!(resolvers);
    }
  }

  List<Widget> _buildHosts() {
    List<Widget> items = [];

    _dnsResolvers.forEach((key, resolver) {
      items.add(
        ConfigItem(
          key: key,
          label: Align(
            alignment: Alignment.centerLeft,
            child: widget.onSave == null
                ? Container()
                : PlatformIconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.remove_circle, color: CupertinoColors.systemRed.resolveFrom(context)),
                    onPressed: () => setState(() {
                      _removeResolver(key);
                      _dismissKeyboard();
                    }),
                  ),
          ),
          labelWidth: 70,
          content: Row(
            children: <Widget>[
              Expanded(
                child: widget.onSave == null
                    ? Text(resolver.address, textAlign: TextAlign.end)
                    : IPFormField(
                        help: 'ip address',
                        textAlign: TextAlign.end,
                        ipOnly: true,
                        //TODO: noBorder: true,
                        initialValue: resolver.address,
                        autoSize: false,
                        onSaved: (v) {
                          if (v != null) {
                            resolver.address = v;
                          }
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    });

    if (widget.onSave != null) {
      items.add(
        ConfigButtonItem(
          content: Text('Add another'),
          onPressed: () => setState(() {
            _addResolver();
            _dismissKeyboard();
          }),
        ),
      );
    }

    return items;
  }

  void _addResolver() {
    changed = true;
    _dnsResolvers[UniqueKey()] = _Resolver(focusNode: FocusNode(), address: "");
    // We can't onChanged here because it causes rendering issues on first build due to ensuring there is a single destination
  }

  void _removeResolver(Key key) {
    changed = true;
    _dnsResolvers.remove(key);
  }

  void _dismissKeyboard() {
    FocusScopeNode currentFocus = FocusScope.of(context);

    if (!currentFocus.hasPrimaryFocus) {
      currentFocus.unfocus();
    }
  }

  @override
  void dispose() {
    _dnsResolvers.forEach((key, resolver) {
      resolver.focusNode.dispose();
    });

    super.dispose();
  }
}
