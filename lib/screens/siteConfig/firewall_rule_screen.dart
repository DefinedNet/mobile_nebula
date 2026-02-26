import 'package:flutter/cupertino.dart' show CupertinoIcons, CupertinoSegmentedControl, CupertinoTextField;
import 'package:flutter/material.dart';
import 'package:mobile_nebula/components/cidr_form_field.dart';
import 'package:mobile_nebula/components/config/config_item.dart';
import 'package:mobile_nebula/components/config/config_page_item.dart';
import 'package:mobile_nebula/components/config/config_section.dart';
import 'package:mobile_nebula/components/danger_button.dart';
import 'package:mobile_nebula/components/form_page.dart';
import 'package:mobile_nebula/components/platform_text_form_field.dart';
import 'package:mobile_nebula/models/cidr.dart';
import 'package:mobile_nebula/models/firewall_rule.dart';
import 'package:mobile_nebula/services/utils.dart';

class FirewallRuleScreen extends StatefulWidget {
  const FirewallRuleScreen({super.key, required this.rule, this.onSave, this.onDelete});

  final FirewallRule rule;
  final ValueChanged<FirewallRule>? onSave;
  final Function? onDelete;

  @override
  FirewallRuleScreenState createState() => FirewallRuleScreenState();
}

class FirewallRuleScreenState extends State<FirewallRuleScreen> {
  late String _protocol;
  late bool _useFragment;
  late String _matchBy; // 'host', 'group', 'cidr'
  late List<String> _groups;
  bool changed = false;

  late String _startPort;
  late String _endPort;
  late String _host;
  late CIDR? _remoteCidr;
  late CIDR? _localCidr;
  late String _caName;
  late String _caSha;

  bool _addingGroup = false;
  final TextEditingController _newGroupController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _protocol = widget.rule.protocol;
    _useFragment = widget.rule.fragment == true;

    if (widget.rule.groups != null && widget.rule.groups!.isNotEmpty) {
      _matchBy = 'group';
    } else if (widget.rule.remoteCidr != null) {
      _matchBy = 'cidr';
    } else {
      _matchBy = 'host';
    }

    _groups = List.from(widget.rule.groups ?? []);
    _startPort = _initialStartPort();
    _endPort = _initialEndPort();
    _host = widget.rule.host ?? '';
    _remoteCidr = widget.rule.remoteCidr;
    _localCidr = widget.rule.localCidr;
    _caName = widget.rule.caName ?? '';
    _caSha = widget.rule.caSha ?? '';
  }

  @override
  void dispose() {
    _newGroupController.dispose();
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

  String _portDisplayValue() {
    if (_useFragment) return 'fragment';
    if (_startPort.isEmpty || _startPort.toLowerCase() == 'any') return 'any';
    if (_endPort.isEmpty) return _startPort;
    return '$_startPort-$_endPort';
  }

  @override
  Widget build(BuildContext context) {
    final readOnly = widget.onSave == null;
    final isNew = widget.onDelete == null;
    return FormPage(
      title: readOnly ? 'View rule' : (isNew ? 'Add rule' : 'Edit rule'),
      changed: changed,
      hideSave: readOnly,
      alwaysShowSave: !readOnly,
      onSave: _onSave,
      child: Column(
        children: [
          _buildTrafficSection(),
          _buildAllowedHostsSection(),
          _buildCertificateAuthoritySection(),
          _buildDeleteButton(),
        ],
      ),
    );
  }

  Widget _buildTrafficSection() {
    final readOnly = widget.onSave == null;
    return ConfigSection(
      label: 'Traffic to match',
      children: [
        ConfigItem(
          labelWidth: 0,
          content: IgnorePointer(
            ignoring: readOnly,
            child: Opacity(
              opacity: readOnly ? 0.6 : 1.0,
              child: CupertinoSegmentedControl<String>(
                children: const {
                  'any': Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Any')),
                  'tcp': Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('TCP')),
                  'udp': Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('UDP')),
                  'icmp': Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('ICMP')),
                },
                groupValue: _protocol,
                onValueChanged: (v) {
                  setState(() {
                    changed = true;
                    _protocol = v;
                  });
                },
              ),
            ),
          ),
        ),
        ConfigItem(
          label: Text('Fragment'),
          labelWidth: 90,
          content: Container(
            alignment: Alignment.centerRight,
            child: Switch.adaptive(
              value: _useFragment,
              onChanged: readOnly
                  ? null
                  : (v) => setState(() {
                      changed = true;
                      _useFragment = v;
                    }),
            ),
          ),
        ),
        if (_protocol != 'icmp' && !_useFragment)
          ConfigPageItem(
            label: Text('Port'),
            disabled: readOnly,
            content: Container(
              alignment: Alignment.centerRight,
              child: Text(_portDisplayValue(), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            onPressed: () => _openPortScreen(),
          ),
      ],
    );
  }

  Widget _buildAllowedHostsSection() {
    final readOnly = widget.onSave == null;
    return ConfigSection(
      label: 'Allowed hosts',
      children: [
        ConfigItem(
          label: Text('Match by'),
          labelWidth: 90,
          content: IgnorePointer(
            ignoring: readOnly,
            child: Opacity(
              opacity: readOnly ? 0.6 : 1.0,
              child: CupertinoSegmentedControl<String>(
                children: const {
                  'host': Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Host')),
                  'group': Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Group')),
                  'cidr': Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('CIDR')),
                },
                groupValue: _matchBy,
                onValueChanged: (v) => setState(() {
                  changed = true;
                  _matchBy = v;
                }),
              ),
            ),
          ),
        ),
        if (_matchBy == 'host')
          ConfigItem(
            label: Text('Host'),
            content: PlatformTextFormField(
              placeholder: 'any',
              initialValue: _host,
              textAlign: TextAlign.end,
              textInputAction: TextInputAction.next,
              enabled: !readOnly,
              onSaved: (v) => _host = v?.trim() ?? '',
            ),
          ),
        if (_matchBy == 'group') _buildGroupChipsItem(readOnly),
        if (_matchBy == 'cidr')
          ConfigItem(
            label: Text('CIDR'),
            content: CIDRFormField(
              initialValue: _remoteCidr,
              textInputAction: TextInputAction.next,
              enabled: !readOnly,
              onSaved: (v) => _remoteCidr = v,
            ),
          ),
        ConfigPageItem(
          label: Text('Local CIDR'),
          labelWidth: 90,
          disabled: readOnly,
          content: Container(
            alignment: Alignment.centerRight,
            child: Text(
              _localCidr?.toString() ?? 'default',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          onPressed: () => _openLocalCidrScreen(),
        ),
      ],
    );
  }

  Widget _buildGroupChipsItem(bool readOnly) {
    final badgeTheme = Theme.of(context).badgeTheme;
    return ConfigItem(
      labelWidth: 0,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _groups.length; i++)
                _buildGroupChip(_groups[i], i, readOnly: readOnly, badgeTheme: badgeTheme),
              if (!readOnly && !_addingGroup) _buildAddPill(badgeTheme),
            ],
          ),
          if (_addingGroup)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      controller: _newGroupController,
                      placeholder: 'group name',
                      autofocus: true,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      onSubmitted: (_) => _confirmAddGroup(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _confirmAddGroup,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.primary),
                      child: Icon(CupertinoIcons.check_mark, color: Theme.of(context).colorScheme.onPrimary, size: 16),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() {
                      _addingGroup = false;
                      _newGroupController.clear();
                    }),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      child: Icon(
                        CupertinoIcons.xmark,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGroupChip(String group, int index, {required bool readOnly, required BadgeThemeData badgeTheme}) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: badgeTheme.backgroundColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(group, style: badgeTheme.textStyle?.copyWith(fontSize: 14)),
          if (!readOnly) ...[
            const SizedBox(width: 4),
            Icon(CupertinoIcons.xmark, color: badgeTheme.textColor, size: 14),
          ],
        ],
      ),
    );

    if (readOnly) return chip;

    return GestureDetector(
      onTap: () => setState(() {
        changed = true;
        _groups.removeAt(index);
      }),
      child: chip,
    );
  }

  Widget _buildAddPill(BadgeThemeData badgeTheme) {
    return GestureDetector(
      onTap: () => setState(() {
        _addingGroup = true;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: badgeTheme.backgroundColor ?? Colors.transparent),
        ),
        child: Text('+ Add', style: badgeTheme.textStyle?.copyWith(fontSize: 14)),
      ),
    );
  }

  void _confirmAddGroup() {
    final text = _newGroupController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        changed = true;
        _groups.add(text);
        _newGroupController.clear();
        _addingGroup = false;
      });
    }
  }

  Widget _buildCertificateAuthoritySection() {
    final readOnly = widget.onSave == null;
    return ConfigSection(
      label: 'Certificate authority',
      children: [
        ConfigItem(
          label: Text('Name'),
          content: PlatformTextFormField(
            placeholder: 'any',
            initialValue: _caName,
            textAlign: TextAlign.end,
            textInputAction: TextInputAction.next,
            enabled: !readOnly,
            onSaved: (v) {
              _caName = v?.trim() ?? '';
            },
          ),
        ),
        ConfigItem(
          label: Text('SHA'),
          content: PlatformTextFormField(
            placeholder: 'any',
            initialValue: _caSha,
            textAlign: TextAlign.end,
            textInputAction: TextInputAction.done,
            enabled: !readOnly,
            onSaved: (v) {
              _caSha = v?.trim() ?? '';
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDeleteButton() {
    if (widget.onDelete == null) return Container();
    return Padding(
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
    );
  }

  void _onSave() {
    final rule = FirewallRule(protocol: _protocol);

    // Port / fragment
    if (_useFragment) {
      rule.fragment = true;
      rule.startPort = 0;
      rule.endPort = 0;
    } else if (_protocol == 'icmp') {
      rule.startPort = 0;
      rule.endPort = 0;
    } else {
      rule.fragment = false;
      final start = _startPort.trim().toLowerCase();
      final end = _endPort.trim();
      if (start.isEmpty || start == 'any') {
        rule.startPort = 0;
        rule.endPort = 0;
      } else {
        final sp = int.parse(start);
        rule.startPort = sp;
        rule.endPort = end.isEmpty ? sp : int.parse(end);
      }
    }

    // Source
    switch (_matchBy) {
      case 'host':
        rule.host = _host.isEmpty ? null : _host;
        rule.groups = null;
        rule.remoteCidr = null;
      case 'group':
        rule.host = null;
        rule.groups = _groups.isEmpty ? null : List.from(_groups);
        rule.remoteCidr = null;
      case 'cidr':
        rule.host = null;
        rule.groups = null;
        rule.remoteCidr = _remoteCidr;
    }

    // Local CIDR
    rule.localCidr = _localCidr;

    // CA
    rule.caName = _caName.isEmpty ? null : _caName;
    rule.caSha = _caSha.isEmpty ? null : _caSha;

    widget.onSave?.call(rule);
    Navigator.pop(context);
  }

  void _openLocalCidrScreen() {
    Utils.openPage(
      context,
      (context) => _LocalCidrScreen(
        initialValue: _localCidr,
        onSave: (v) => setState(() {
          changed = true;
          _localCidr = v;
        }),
      ),
    );
  }

  void _openPortScreen() {
    Utils.openPage(
      context,
      (context) => _PortScreen(
        startPort: _startPort,
        endPort: _endPort,
        onSave: (start, end) => setState(() {
          changed = true;
          _startPort = start;
          _endPort = end;
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Port sub-screen
// ---------------------------------------------------------------------------

class _PortScreen extends StatefulWidget {
  const _PortScreen({required this.startPort, required this.endPort, required this.onSave});

  final String startPort;
  final String endPort;
  final void Function(String start, String end) onSave;

  @override
  _PortScreenState createState() => _PortScreenState();
}

class _PortScreenState extends State<_PortScreen> {
  late TextEditingController _startController;
  late String _endPortRaw;
  bool changed = false;

  @override
  void initState() {
    super.initState();
    _startController = TextEditingController(text: widget.startPort);
    _endPortRaw = widget.endPort;
  }

  @override
  void dispose() {
    _startController.dispose();
    super.dispose();
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
    final startStr = _startController.text.trim().toLowerCase();
    if (startStr.isEmpty || startStr == 'any') return 'Start port is required when end port is set';
    final p = int.tryParse(val.trim());
    if (p == null) return 'Invalid port';
    if (p < 0 || p > 65535) return 'Port out of range (0-65535)';
    final start = int.tryParse(startStr);
    if (start != null && p < start) return 'Must be >= start port';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'Port',
      changed: changed,
      onSave: () {
        widget.onSave(_startController.text.trim(), _endPortRaw.trim());
        Navigator.pop(context);
      },
      child: ConfigSection(
        children: [
          ConfigItem(
            label: Text('Start port'),
            content: PlatformTextFormField(
              controller: _startController,
              placeholder: 'any',
              textAlign: TextAlign.end,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.number,
              validator: _startPortValidator,
            ),
          ),
          ConfigItem(
            label: Text('End port'),
            content: PlatformTextFormField(
              placeholder: 'same as start',
              initialValue: _endPortRaw,
              textAlign: TextAlign.end,
              textInputAction: TextInputAction.done,
              keyboardType: TextInputType.number,
              validator: _endPortValidator,
              onSaved: (v) => _endPortRaw = v ?? '',
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Local CIDR sub-screen
// ---------------------------------------------------------------------------

class _LocalCidrScreen extends StatefulWidget {
  const _LocalCidrScreen({required this.initialValue, required this.onSave});

  final CIDR? initialValue;
  final ValueChanged<CIDR?> onSave;

  @override
  _LocalCidrScreenState createState() => _LocalCidrScreenState();
}

class _LocalCidrScreenState extends State<_LocalCidrScreen> {
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
        // Treat empty CIDR as null so the UI shows "default"
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
