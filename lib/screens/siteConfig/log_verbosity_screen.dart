import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_nebula/components/config/config_checkbox_item.dart';
import 'package:mobile_nebula/components/config/config_section.dart';
import 'package:mobile_nebula/components/form_page.dart';

class LogVerbosityScreen extends StatefulWidget {
  const LogVerbosityScreen({super.key, required this.verbosity, required this.onSave});

  final String verbosity;
  final ValueChanged<String> onSave;

  @override
  LogVerbosityScreenState createState() => LogVerbosityScreenState();
}

class LogVerbosityScreenState extends State<LogVerbosityScreen> {
  late String verbosity;
  bool changed = false;

  @override
  void initState() {
    verbosity = widget.verbosity;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'Log Verbosity',
      changed: changed,
      onSave: () {
        Navigator.pop(context);
        widget.onSave(verbosity);
      },
      child: Column(
        children: <Widget>[
          ConfigSection(
            children: [
              _buildEntry('debug'),
              _buildEntry('info'),
              _buildEntry('warning'),
              _buildEntry('error'),
              _buildEntry('fatal'),
              _buildEntry('panic'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEntry(String title) {
    return ConfigCheckboxItem(
      label: Text(title),
      labelWidth: 150,
      checked: verbosity == title,
      onChanged: () {
        setState(() {
          changed = true;
          verbosity = title;
        });
      },
    );
  }
}
