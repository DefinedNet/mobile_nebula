import 'dart:io';

import 'package:flutter/material.dart';
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

class _Domain {
  final FocusNode focusNode;
  String domain;

  _Domain({required this.focusNode, required this.domain});
}

class DnsResolversScreen extends StatefulWidget {
  DnsResolversScreen({super.key, dnsResolvers, matchDomains, required this.onSave, this.onSaveMatchDomains})
    : dnsResolvers = dnsResolvers ?? [],
      matchDomains = matchDomains ?? [];

  final List<String> dnsResolvers;
  final List<String> matchDomains;
  final ValueChanged<List<String>>? onSave;
  final ValueChanged<List<String>>? onSaveMatchDomains;

  @override
  DnsResolversScreenState createState() => DnsResolversScreenState();
}

class DnsResolversScreenState extends State<DnsResolversScreen> {
  late Map<Key, _Resolver> _dnsResolvers;
  late Map<Key, _Domain> _matchDomains;
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

    _matchDomains = {};
    for (var domain in widget.matchDomains) {
      _matchDomains[UniqueKey()] = _Domain(focusNode: FocusNode(), domain: domain);
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
          if (Platform.isIOS)
            ConfigSection(
              label:
                  'Domains to route through the VPN\'s DNS resolvers.\nWhen empty, all DNS queries are routed through the VPN.',
              children: _buildDomains(),
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

    if (widget.onSaveMatchDomains != null) {
      List<String> domains = [];
      _matchDomains.forEach((_, domain) {
        final value = domain.domain.trim();
        if (value.isNotEmpty) {
          domains.add(value);
        }
      });

      widget.onSaveMatchDomains!(domains);
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
                : IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.remove_circle, color: Theme.of(context).colorScheme.error),
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

  List<Widget> _buildDomains() {
    List<Widget> items = [];

    _matchDomains.forEach((key, domain) {
      items.add(
        ConfigItem(
          key: key,
          label: Align(
            alignment: Alignment.centerLeft,
            child: widget.onSaveMatchDomains == null
                ? Container()
                : IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.remove_circle, color: Theme.of(context).colorScheme.error),
                    onPressed: () => setState(() {
                      _removeDomain(key);
                      _dismissKeyboard();
                    }),
                  ),
          ),
          labelWidth: 70,
          content: Row(
            children: <Widget>[
              Expanded(
                child: widget.onSaveMatchDomains == null
                    ? Text(domain.domain, textAlign: TextAlign.end)
                    : TextFormField(
                        initialValue: domain.domain,
                        textAlign: TextAlign.end,
                        autocorrect: false,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(border: InputBorder.none, hintText: 'example.com'),
                        onSaved: (v) {
                          if (v != null) {
                            domain.domain = v;
                          }
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    });

    if (widget.onSaveMatchDomains != null) {
      items.add(
        ConfigButtonItem(
          content: Text('Add another'),
          onPressed: () => setState(() {
            _addDomain();
            _dismissKeyboard();
          }),
        ),
      );
    }

    return items;
  }

  void _addDomain() {
    changed = true;
    _matchDomains[UniqueKey()] = _Domain(focusNode: FocusNode(), domain: "");
  }

  void _removeDomain(Key key) {
    changed = true;
    _matchDomains.remove(key);
  }

  @override
  void dispose() {
    _dnsResolvers.forEach((key, resolver) {
      resolver.focusNode.dispose();
    });
    _matchDomains.forEach((key, domain) {
      domain.focusNode.dispose();
    });

    super.dispose();
  }
}
