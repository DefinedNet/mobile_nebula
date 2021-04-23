import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_nebula/components/FormPage.dart';
import 'package:mobile_nebula/components/config/ConfigCheckboxItem.dart';
import 'package:mobile_nebula/components/config/ConfigSection.dart';

class LogVerbosityScreen extends StatefulWidget {
  const LogVerbosityScreen({Key key, this.verbosity, @required this.onSave}) : super(key: key);

  final String verbosity;
  final ValueChanged<String> onSave;

  @override
  _LogVerbosityScreenState createState() => _LogVerbosityScreenState();
}

class _LogVerbosityScreenState extends State<LogVerbosityScreen> {
  String verbosity;
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
          if (widget.onSave != null) {
            widget.onSave(verbosity);
          }
        },
        child: Column(
          children: <Widget>[
            ConfigSection(children: [
              _buildEntry('debug'),
              _buildEntry('info'),
              _buildEntry('warning'),
              _buildEntry('error'),
              _buildEntry('fatal'),
              _buildEntry('panic'),
            ])
          ],
        ));
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
