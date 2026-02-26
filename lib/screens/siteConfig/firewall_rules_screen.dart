import 'package:flutter/cupertino.dart';
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
      trailingActions: widget.onSave != null ? [_buildAddButton(context)] : null,
      child: ConfigSection(children: _buildRules()),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      child: const Icon(CupertinoIcons.add),
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
    );
  }

  void _onSave() {
    Navigator.pop(context);
    if (widget.onSave != null) {
      widget.onSave!(rules.values.toList());
    }
  }

  String _ruleTitle(FirewallRule rule) {
    final protocol = rule.protocol == 'any' ? 'Any' : rule.protocol.toUpperCase();

    String port;
    if (rule.fragment == true) {
      port = 'fragment';
    } else if (rule.startPort == 0 && rule.endPort == 0) {
      port = 'any';
    } else if (rule.startPort == rule.endPort) {
      port = '${rule.startPort}';
    } else {
      port = '${rule.startPort}-${rule.endPort}';
    }

    return '$protocol:$port';
  }

  String _ruleSubtitle(FirewallRule rule) {
    final parts = <String>[];

    if (rule.groups != null && rule.groups!.isNotEmpty) {
      parts.add(rule.groups!.join(' + '));
    }

    if (rule.host != null && rule.host!.isNotEmpty && rule.host != 'any') {
      parts.add(rule.host!);
    }

    if (rule.remoteCidr != null) {
      parts.add(rule.remoteCidr.toString());
    }

    if (parts.isEmpty) {
      return 'Any source allowed';
    }

    return parts.join(' \u2022 ');
  }

  bool _hasAdvancedSettings(FirewallRule rule) {
    return rule.caName != null || rule.caSha != null || rule.localCidr != null || rule.fragment == true;
  }

  List<Widget> _buildRules() {
    List<Widget> items = [];

    rules.forEach((key, rule) {
      items.add(
        ConfigPageItem(
          content: _buildRuleContent(context, rule),
          onPressed: () {
            Utils.openPage(context, (context) {
              return FirewallRuleScreen(
                rule: rule,
                onSave: widget.onSave == null
                    ? null
                    : (updated) {
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

    return items;
  }

  Widget _buildRuleContent(BuildContext context, FirewallRule rule) {
    final hasAdvanced = _hasAdvancedSettings(rule);
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(_ruleTitle(rule), style: const TextStyle(fontWeight: FontWeight.bold)),
            if (hasAdvanced)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBlue.resolveFrom(context),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(_ruleSubtitle(rule), style: TextStyle(color: secondaryColor, fontSize: 14)),
      ],
    );
  }
}
