import 'package:flutter/cupertino.dart';
import 'package:mobile_nebula/components/config/config_button_item.dart';
import 'package:mobile_nebula/components/config/config_page_item.dart';
import 'package:mobile_nebula/components/config/config_section.dart';
import 'package:mobile_nebula/components/form_page.dart';
import 'package:mobile_nebula/models/firewall_rule.dart';
import 'package:mobile_nebula/screens/siteConfig/firewall_rule_screen.dart';
import 'package:mobile_nebula/services/utils.dart';

class FirewallRulesScreen extends StatefulWidget {
  const FirewallRulesScreen({super.key, required this.title, required this.rules, required this.onSave});

  final String title;
  final List<FirewallRule> rules;
  final ValueChanged<List<FirewallRule>>? onSave;

  @override
  State<FirewallRulesScreen> createState() => _FirewallRulesScreenState();
}

class _FirewallRulesScreenState extends State<FirewallRulesScreen> {
  late Map<Key, FirewallRule> rules;
  bool changed = false;

  @override
  void initState() {
    rules = {};
    for (var rule in widget.rules) {
      rules[UniqueKey()] = rule;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: widget.title,
      changed: changed,
      onSave: _onSave,
      child: ConfigSection(children: _buildRules()),
    );
  }

  void _onSave() {
    Navigator.pop(context);
    if (widget.onSave != null) {
      widget.onSave!(rules.values.toList());
    }
  }

  String _portLabel(FirewallRule rule) {
    if (rule.fragment == true) return 'fragment';
    if (rule.startPort == 0 && rule.endPort == 0) return 'any';
    if (rule.startPort == rule.endPort) return '${rule.startPort}';
    return '${rule.startPort}-${rule.endPort}';
  }

  String _targetLabel(FirewallRule rule) {
    if (rule.groups != null && rule.groups!.isNotEmpty) return rule.groups!.join(' + ');
    if (rule.host != null && rule.host!.isNotEmpty && rule.host != 'any') return rule.host!;
    //TODO: we need to do something with localCidr as well, and make sure it fits in the config language
    if (rule.remoteCidr != null) return rule.remoteCidr.toString();
    return 'any';
  }

  List<Widget> _buildRules() {
    List<Widget> items = [];

    rules.forEach((key, rule) {
      items.add(
        ConfigPageItem(
          disabled: widget.onSave == null,
          label: Text('${rule.protocol} / ${_portLabel(rule)}'),
          content: Text(_targetLabel(rule), textAlign: TextAlign.end),
          onPressed: () {
            Utils.openPage(context, (context) {
              return FirewallRuleScreen(
                rule: rule,
                onSave: (updated) {
                  setState(() {
                    changed = true;
                    rules[key] = updated;
                  });
                },
                onDelete: widget.onSave == null
                    ? null
                    : () {
                        setState(() {
                          changed = true;
                          rules.remove(key);
                        });
                      },
              );
            });
          },
        ),
      );
    });

    if (widget.onSave != null) {
      items.add(
        ConfigButtonItem(
          content: const Text('Add a new rule'),
          onPressed: () {
            Utils.openPage(context, (context) {
              return FirewallRuleScreen(
                rule: FirewallRule(),
                onSave: (rule) {
                  setState(() {
                    changed = true;
                    rules[UniqueKey()] = rule;
                  });
                },
              );
            });
          },
        ),
      );
    }

    return items;
  }
}
