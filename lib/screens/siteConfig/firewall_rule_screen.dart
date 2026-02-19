import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart' hide PlatformTextFormField;
import 'package:mobile_nebula/components/config/config_button_item.dart';
import 'package:mobile_nebula/components/config/config_item.dart';
import 'package:mobile_nebula/components/config/config_section.dart';
import 'package:mobile_nebula/components/danger_button.dart';
import 'package:mobile_nebula/components/form_page.dart';
import 'package:mobile_nebula/components/platform_text_form_field.dart';
import 'package:mobile_nebula/errors/parse_error.dart';
import 'package:mobile_nebula/models/cidr.dart';
import 'package:mobile_nebula/models/firewall_rule.dart';
import 'package:mobile_nebula/services/utils.dart';

class FirewallRuleScreen extends StatefulWidget {
  const FirewallRuleScreen({
    super.key,
    required this.rule,
    required this.onSave,
    this.onDelete,
  });

  final FirewallRule rule;
  final ValueChanged<FirewallRule> onSave;
  final Function? onDelete;

  @override
  FirewallRuleScreenState createState() => FirewallRuleScreenState();
}

class FirewallRuleScreenState extends State<FirewallRuleScreen> {
  late String _protocol;
  late bool _useFragment;
  late bool _useGroups;
  late Map<Key, TextEditingController> _groups;
  bool changed = false;

  // Captured from port field onSaved callbacks, combined in _onSave
  String _startPortRaw = '';
  String _endPortRaw = '';

  // Accumulated by form field onSaved callbacks and _onSave
  late FirewallRule _rule;

  @override
  void initState() {
    _protocol = widget.rule.protocol;
    _useFragment = widget.rule.fragment == true;
    _useGroups = widget.rule.groups != null && widget.rule.groups!.isNotEmpty;
    _startPortRaw = _initialStartPort();
    _endPortRaw = _initialEndPort();
    _rule = FirewallRule(
      protocol: widget.rule.protocol,
      startPort: widget.rule.startPort,
      endPort: widget.rule.endPort,
      fragment: widget.rule.fragment,
      host: widget.rule.host,
      groups: widget.rule.groups != null ? List.from(widget.rule.groups!) : null,
      localCidr: widget.rule.localCidr,
      remoteCidr: widget.rule.remoteCidr,
      caName: widget.rule.caName,
      caSha: widget.rule.caSha,
    );
    _groups = {};
    for (var group in widget.rule.groups ?? []) {
      _groups[UniqueKey()] = TextEditingController(text: group);
    }
    super.initState();
  }

  @override
  void dispose() {
    for (var controller in _groups.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _initialStartPort() {
    if (widget.rule.startPort == 0 && widget.rule.endPort == 0) return '';
    return '${widget.rule.startPort}';
  }

  String _initialEndPort() {
    if (widget.rule.startPort == 0 && widget.rule.endPort == 0) return '';
    if (widget.rule.startPort == widget.rule.endPort) return '';
    return '${widget.rule.endPort}';
  }

  String? _startPortValidator(String? val) {
    final str = val?.trim().toLowerCase() ?? '';
    if (str.isEmpty || str == 'any') return null;
    final p = int.tryParse(str);
    if (p == null) return 'Invalid port';
    if (p < 0 || p > 65535) return 'Port out of range (0-65535)';
    return null;
  }

  String? _endPortValidator(String? val) {
    if (val == null || val.trim().isEmpty) return null;
    final p = int.tryParse(val.trim());
    if (p == null) return 'Invalid port';
    if (p < 0 || p > 65535) return 'Port out of range (0-65535)';
    return null;
  }

  void _parsePortInputs() {
    if (_useFragment) {
      _rule.fragment = true;
      _rule.startPort = 0;
      _rule.endPort = 0;
      return;
    }
    final start = _startPortRaw.trim().toLowerCase();
    final end = _endPortRaw.trim();
    _rule.fragment = false;
    if (start.isEmpty || start == 'any') {
      _rule.startPort = 0;
      _rule.endPort = 0;
    } else {
      final sp = int.parse(start);
      _rule.startPort = sp;
      _rule.endPort = end.isEmpty ? sp : int.parse(end);
    }
  }

  String? _cidrValidator(String? val) {
    if (val == null || val.trim().isEmpty) return null;
    try {
      CIDR.fromString(val.trim());
      return null;
    } on ParseError catch (e) {
      return e.message;
    }
  }

  void _dismissKeyboard() {
    final currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus) {
      currentFocus.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: widget.onDelete == null ? 'New Rule' : 'Edit Rule',
      changed: changed,
      onSave: _onSave,
      child: Column(
        children: [
          ConfigSection(
            label: 'Traffic to match',
            children: [
              ConfigItem(
                label: Text('Protocol'),
                labelWidth: 90,
                content: CupertinoSegmentedControl<String>(
                  children: const {
                    'any': Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('Any'),
                    ),
                    'tcp': Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('TCP'),
                    ),
                    'udp': Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('UDP'),
                    ),
                    'icmp': Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('ICMP'),
                    ),
                  },
                  groupValue: _protocol,
                  onValueChanged: (v) {
                    setState(() {
                      changed = true;
                      _protocol = v;
                      _rule.protocol = v;
                    });
                  },
                ),
              ),
              ConfigItem(
                label: Text('Fragment'),
                labelWidth: 90,
                content: Container(
                  alignment: Alignment.centerRight,
                  child: Switch.adaptive(
                    value: _useFragment,
                    onChanged: (v) => setState(() {
                      changed = true;
                      _useFragment = v;
                      _dismissKeyboard();
                    }),
                  ),
                ),
              ),
              if (_protocol != 'icmp' && !_useFragment) ...[
                ConfigItem(
                  label: Text('Start port'),
                  content: PlatformTextFormField(
                    placeholder: 'any',
                    initialValue: _startPortRaw,
                    textAlign: TextAlign.end,
                    textInputAction: TextInputAction.next,
                    validator: _startPortValidator,
                    onSaved: (v) => _startPortRaw = v ?? '',
                  ),
                ),
                ConfigItem(
                  label: Text('End port'),
                  content: PlatformTextFormField(
                    placeholder: 'same as start',
                    initialValue: _endPortRaw,
                    textAlign: TextAlign.end,
                    textInputAction: TextInputAction.next,
                    validator: _endPortValidator,
                    onSaved: (v) => _endPortRaw = v ?? '',
                  ),
                ),
              ],
            ],
          ),
          ConfigSection(label: 'Allowed hosts', children: _buildAllowedHosts()),
          ConfigSection(
            label: 'CA',
            children: [
              ConfigItem(
                label: Text('CA Name'),
                content: PlatformTextFormField(
                  placeholder: 'any',
                  initialValue: widget.rule.caName ?? '',
                  textAlign: TextAlign.end,
                  textInputAction: TextInputAction.next,
                  onSaved: (v) {
                    _rule.caName = (v == null || v.trim().isEmpty) ? null : v.trim();
                  },
                ),
              ),
              ConfigItem(
                label: Text('CA SHA'),
                content: PlatformTextFormField(
                  placeholder: 'any',
                  initialValue: widget.rule.caSha ?? '',
                  textAlign: TextAlign.end,
                  textInputAction: TextInputAction.done,
                  onSaved: (v) {
                    _rule.caSha = (v == null || v.trim().isEmpty) ? null : v.trim();
                  },
                ),
              ),
            ],
          ),
          widget.onDelete != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 50, bottom: 10, left: 10, right: 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: DangerButton(
                      child: const Text('Delete Rule'),
                      onPressed: () => Utils.confirmDelete(context, 'Delete firewall rule?', () {
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

  void _onSave() {
    if (_useGroups) {
      final groups = _groups.values.map((c) => c.text.trim()).where((g) => g.isNotEmpty).toList();
      _rule.groups = groups.isEmpty ? null : groups;
      _rule.host = null;
    } else {
      _rule.groups = null;
      // _rule.host is set by the host field's onSaved
    }

    _parsePortInputs();
    Navigator.pop(context);
    widget.onSave(_rule);
  }

  List<Widget> _buildAllowedHosts() {
    List<Widget> items = [];

    items.add(
      ConfigItem(
        label: Text('Match by'),
        labelWidth: 90,
        content: CupertinoSegmentedControl<bool>(
          children: const {
            false: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('Host'),
            ),
            true: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('Group'),
            ),
          },
          groupValue: _useGroups,
          onValueChanged: (v) => setState(() {
            changed = true;
            _useGroups = v;
            _dismissKeyboard();
          }),
        ),
      ),
    );

    if (!_useGroups) {
      items.add(
        ConfigItem(
          label: Text('Host'),
          content: PlatformTextFormField(
            placeholder: 'any',
            initialValue: widget.rule.host ?? '',
            textAlign: TextAlign.end,
            textInputAction: TextInputAction.next,
            onSaved: (v) {
              _rule.host = (v == null || v.trim().isEmpty) ? null : v.trim();
            },
          ),
        ),
      );
    } else {
      _groups.forEach((key, controller) {
        items.add(
          ConfigItem(
            key: key,
            label: Align(
              alignment: Alignment.centerLeft,
              child: PlatformIconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.remove_circle, color: CupertinoColors.systemRed.resolveFrom(context)),
                onPressed: () => setState(() {
                  changed = true;
                  controller.dispose();
                  _groups.remove(key);
                  _dismissKeyboard();
                }),
              ),
            ),
            labelWidth: 70,
            content: PlatformTextFormField(
              controller: controller,
              placeholder: 'group name',
              textAlign: TextAlign.end,
            ),
          ),
        );
      });

      items.add(
        ConfigButtonItem(
          content: const Text('Add a group'),
          onPressed: () => setState(() {
            changed = true;
            _groups[UniqueKey()] = TextEditingController();
            _dismissKeyboard();
          }),
        ),
      );
    }

    items.add(
      ConfigItem(
        label: Text('Remote CIDR'),
        labelWidth: 120,
        content: PlatformTextFormField(
          placeholder: 'any',
          initialValue: widget.rule.remoteCidr?.toString() ?? '',
          textAlign: TextAlign.end,
          textInputAction: TextInputAction.next,
          validator: _cidrValidator,
          onSaved: (v) {
            if (v == null || v.trim().isEmpty) {
              _rule.remoteCidr = null;
            } else {
              try {
                _rule.remoteCidr = CIDR.fromString(v.trim());
              } on ParseError {
                // Already rejected by validator
              }
            }
          },
        ),
      ),
    );

    items.add(
      ConfigItem(
        label: Text('Local CIDR'),
        labelWidth: 120,
        content: PlatformTextFormField(
          placeholder: 'any',
          initialValue: widget.rule.localCidr?.toString() ?? '',
          textAlign: TextAlign.end,
          textInputAction: TextInputAction.next,
          validator: _cidrValidator,
          onSaved: (v) {
            if (v == null || v.trim().isEmpty) {
              _rule.localCidr = null;
            } else {
              try {
                _rule.localCidr = CIDR.fromString(v.trim());
              } on ParseError {
                // Already rejected by validator
              }
            }
          },
        ),
      ),
    );

    return items;
  }
}
