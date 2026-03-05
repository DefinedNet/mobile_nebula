import 'package:flutter/material.dart';
import 'package:mobile_nebula/components/app_text_form_field.dart';
import 'package:mobile_nebula/components/cidr_form_field.dart';
import 'package:mobile_nebula/components/config/config_item.dart';
import 'package:mobile_nebula/components/config/config_page_item.dart';
import 'package:mobile_nebula/components/config/config_section.dart';
import 'package:mobile_nebula/components/danger_button.dart';
import 'package:mobile_nebula/components/form_page.dart';
import 'package:mobile_nebula/components/pill_chip.dart';
import 'package:mobile_nebula/components/pill_segmented_button.dart';
import 'package:mobile_nebula/models/cidr.dart';
import 'package:mobile_nebula/models/firewall_rule.dart';
import 'package:mobile_nebula/screens/siteConfig/firewall_local_cidr_screen.dart';
import 'package:mobile_nebula/screens/siteConfig/firewall_port_screen.dart';
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
  late final TextEditingController _hostController;
  late TextStyle _labelStyle;

  @override
  void initState() {
    super.initState();
    _protocol = widget.rule.proto;
    _useFragment = widget.rule.port == 'fragment';

    if (widget.rule.groups != null && widget.rule.groups!.isNotEmpty) {
      _matchBy = 'group';
    } else if (widget.rule.cidr != null) {
      _matchBy = 'cidr';
    } else {
      _matchBy = 'host';
    }

    _groups = List.from(widget.rule.groups ?? []);
    _startPort = _initialStartPort();
    _endPort = _initialEndPort();
    _host = widget.rule.host ?? '';
    _hostController = TextEditingController(text: _host);
    _remoteCidr = _parseCidr(widget.rule.cidr);
    _localCidr = _parseCidr(widget.rule.localCidr);
    _caName = widget.rule.caName ?? '';
    _caSha = widget.rule.caSha ?? '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _labelStyle = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);
  }

  @override
  void dispose() {
    _newGroupController.dispose();
    _hostController.dispose();
    super.dispose();
  }

  static CIDR? _parseCidr(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return CIDR.fromString(value);
    } catch (_) {
      return null;
    }
  }

  String _initialStartPort() {
    final port = widget.rule.port;
    if (port == 'any' || port == 'fragment') return '';
    if (port.contains('-')) return port.split('-')[0];
    return port;
  }

  String _initialEndPort() {
    final port = widget.rule.port;
    if (port == 'any' || port == 'fragment') return '';
    if (port.contains('-')) return port.split('-')[1];
    return '';
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
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Protocol', style: _labelStyle),
              ),
              const SizedBox(height: 6),
              IgnorePointer(
                ignoring: readOnly,
                child: Opacity(
                  opacity: readOnly ? 0.6 : 1.0,
                  child: PillSegmentedButton<String>(
                    segments: [
                      (value: 'any', label: Text('Any')),
                      (value: 'tcp', label: Text('TCP')),
                      (value: 'udp', label: Text('UDP')),
                      (value: 'icmp', label: Text('ICMP')),
                    ],
                    selected: {_protocol},
                    onSelectionChanged: (v) {
                      setState(() {
                        changed = true;
                        _protocol = v.first;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        ConfigPageItem(
          label: Text('Local CIDR', style: _labelStyle),
          labelWidth: 90,
          disabled: readOnly,
          content: Container(alignment: Alignment.centerRight, child: Text(_localCidr?.toString() ?? 'default')),
          onPressed: () => _openLocalCidrScreen(),
        ),
        ConfigItem(
          label: Text('Fragment', style: _labelStyle),
          labelWidth: 90,
          padding: EdgeInsets.symmetric(horizontal: 15),
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
            label: Text('Port', style: _labelStyle),
            disabled: readOnly,
            content: Container(alignment: Alignment.centerRight, child: Text(_portDisplayValue())),
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
          labelWidth: 0,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Match by', style: _labelStyle),
              ),
              const SizedBox(height: 6),
              IgnorePointer(
                ignoring: readOnly,
                child: Opacity(
                  opacity: readOnly ? 0.6 : 1.0,
                  child: PillSegmentedButton<String>(
                    segments: [
                      (value: 'host', label: Text('Host')),
                      (value: 'group', label: Text('Group')),
                      (value: 'cidr', label: Text('CIDR')),
                    ],
                    selected: {_matchBy},
                    onSelectionChanged: (v) => setState(() {
                      changed = true;
                      _matchBy = v.first;
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_matchBy == 'host')
                TextField(
                  controller: _hostController,
                  enabled: !readOnly,
                  textInputAction: TextInputAction.next,
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.normal),
                  decoration: InputDecoration(
                    hintText: 'any',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                    ),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {
                    changed = true;
                  }),
                ),
              if (_matchBy == 'group') _buildGroupChips(readOnly),
              if (_matchBy == 'cidr')
                Container(
                  constraints: const BoxConstraints(minHeight: 40),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: CIDRFormField(
                    initialValue: _remoteCidr,
                    textInputAction: TextInputAction.next,
                    enabled: !readOnly,
                    onSaved: (v) => _remoteCidr = v,
                  ),
                ),
              SizedBox(height: 10),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGroupChips(bool readOnly) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _groups.length; i++) _buildGroupChip(_groups[i], i, readOnly: readOnly),
            if (!readOnly && !_addingGroup) _buildAddPill(),
            if (_addingGroup)
              _buildInlineTextField(
                controller: _newGroupController,
                hintText: 'group name',
                onConfirm: _confirmAddGroup,
                onCancel: () => setState(() {
                  _addingGroup = false;
                  _newGroupController.clear();
                }),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildGroupChip(String group, int index, {required bool readOnly}) {
    if (readOnly) {
      return PillChip(label: group);
    }

    return PillChip(
      label: group,
      trailingIcon: Icons.close,
      onTap: () => setState(() {
        changed = true;
        _groups.removeAt(index);
      }),
    );
  }

  Widget _buildAddPill() {
    return PillChip(
      label: '+ Add',
      border: PillChipBorder.dashed,
      onTap: () => setState(() {
        _addingGroup = true;
      }),
    );
  }

  Widget _buildInlineTextField({
    required TextEditingController controller,
    required String hintText,
    required VoidCallback onConfirm,
    required VoidCallback onCancel,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: true,
            style: Theme.of(context).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.normal),
            decoration: InputDecoration(
              hintText: hintText,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.surfaceContainerHighest),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.surfaceContainerHighest),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.surfaceContainerHighest),
              ),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => onConfirm(),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              _buildInlineButton(icon: Icons.check, active: controller.text.trim().isNotEmpty, onTap: onConfirm),
              _buildInlineButton(icon: Icons.close, active: false, onTap: onCancel),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInlineButton({required IconData icon, required bool active, required VoidCallback onTap}) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 48,
      height: 40,
      child: Material(
        color: active ? colorScheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Icon(icon, color: active ? colorScheme.onPrimary : colorScheme.onSecondaryContainer, size: 18),
        ),
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
          label: Text('Name', style: _labelStyle),
          content: AppTextFormField(
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
          label: Text('SHA', style: _labelStyle),
          content: AppTextFormField(
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
    // Build port string
    String port;
    if (_useFragment) {
      port = 'fragment';
    } else if (_protocol == 'icmp') {
      port = 'any';
    } else {
      final start = _startPort.trim().toLowerCase();
      final end = _endPort.trim();
      if (start.isEmpty || start == 'any') {
        port = 'any';
      } else if (end.isEmpty) {
        port = start;
      } else {
        port = '$start-$end';
      }
    }

    final rule = FirewallRule(port: port, proto: _protocol);

    // Source
    switch (_matchBy) {
      case 'host':
        final host = _hostController.text.trim();
        rule.host = host.isEmpty ? null : host;
      case 'group':
        rule.groups = _groups.isEmpty ? null : List.from(_groups);
      case 'cidr':
        rule.cidr = _remoteCidr?.toString();
    }

    // Local CIDR
    rule.localCidr = _localCidr?.toString();

    // CA
    rule.caName = _caName.isEmpty ? null : _caName;
    rule.caSha = _caSha.isEmpty ? null : _caSha;

    // Rule-level validation (port+proto combined checks)
    final validationError = rule.validate();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    widget.onSave?.call(rule);
    Navigator.pop(context);
  }

  void _openLocalCidrScreen() {
    Utils.openPage(
      context,
      (context) => FirewallLocalCidrScreen(
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
      (context) => FirewallPortScreen(
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
