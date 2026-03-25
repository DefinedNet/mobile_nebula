import 'package:flutter/material.dart';
import 'package:mobile_nebula/components/config/config_item.dart';
import 'package:mobile_nebula/components/config/config_section.dart';
import 'package:mobile_nebula/components/form_page.dart';
import 'package:mobile_nebula/components/app_text_form_field.dart';

class FirewallPortScreen extends StatefulWidget {
  const FirewallPortScreen({super.key, required this.startPort, required this.endPort, required this.onSave});

  final String startPort;
  final String endPort;
  final void Function(String start, String end) onSave;

  @override
  State<FirewallPortScreen> createState() => _FirewallPortScreenState();
}

class _FirewallPortScreenState extends State<FirewallPortScreen> {
  late TextEditingController _startController;
  late String _endPortRaw;
  bool changed = false;
  final _endPortKey = GlobalKey<FormFieldState<String>>();

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
    if (p < 1 || p > 65535) return 'Port out of range (1-65535)';
    return null;
  }

  String? _endPortValidator(String? val) {
    if (val == null || val.trim().isEmpty) return null;
    final startStr = _startController.text.trim().toLowerCase();
    if (startStr.isEmpty || startStr == 'any') return 'Start port is required when end port is set';
    final p = int.tryParse(val.trim());
    if (p == null) return 'Invalid port';
    if (p < 1 || p > 65535) return 'Port out of range (1-65535)';
    final start = int.tryParse(startStr);
    if (start != null && p <= start) return 'Must be > start port';
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
            content: AppTextFormField(
              controller: _startController,
              placeholder: 'any',
              textAlign: TextAlign.end,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.number,
              validator: _startPortValidator,
              onChanged: (v) {
                setState(() {
                  changed = true;
                });
                // Revalidate end port when start port changes
                _endPortKey.currentState?.validate();
              },
            ),
          ),
          ConfigItem(
            label: Text('End port'),
            content: AppTextFormField(
              key: _endPortKey,
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
