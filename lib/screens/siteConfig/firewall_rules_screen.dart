import 'package:flutter/material.dart';
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
    final editable = widget.onSave != null;
    return FormPage(
      title: widget.title,
      changed: changed,
      onSave: _onSave,
      bottomBar: editable ? _buildAddRuleButton(context) : null,
      child: ConfigSection(children: _buildRules()),
    );
  }

  Widget _buildAddRuleButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8, right: 32),
      child: Align(
        alignment: Alignment.centerRight,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            padding: EdgeInsets.fromLTRB(10, 12, 16, 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          child: Text.rich(
            TextSpan(
              children: [
                WidgetSpan(
                  //TODO: light mode color: rgba(190, 167, 241, 1), dark mode: rgba(190, 167, 241, 1)
                  child: Icon(Icons.add, size: 20, color: colorScheme.onPrimary),
                  alignment: PlaceholderAlignment.middle,
                ),
                const TextSpan(text: ' Add rule'),
              ],
            ),
          ),
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
      ),
    );
  }

  void _onSave() {
    Navigator.pop(context);
    if (widget.onSave != null) {
      widget.onSave!(rules.values.toList());
    }
  }

  String _ruleTitle(FirewallRule rule) {
    if (rule.description != null && rule.description!.isNotEmpty) {
      return rule.description!;
    }
    return 'No description';
  }

  String _ruleSummary(FirewallRule rule) {
    final protocol = rule.proto == 'any' ? 'Any' : rule.proto.toUpperCase();
    final port = rule.port == 'any' ? 'any' : rule.port;
    return '$protocol:$port';
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
    final secondaryColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_ruleTitle(rule), style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(_ruleSummary(rule), style: TextStyle(color: secondaryColor, fontSize: 14)),
      ],
    );
  }
}
