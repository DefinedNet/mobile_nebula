import 'package:flutter/material.dart';
import 'package:mobile_nebula/services/utils.dart';

import 'ConfigHeader.dart';

class ConfigSection extends StatelessWidget {
  const ConfigSection({Key key, this.label, this.children, this.borderColor, this.labelColor}) : super(key: key);

  final List<Widget> children;
  final String label;
  final Color borderColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    final border = BorderSide(color: borderColor ?? Utils.configSectionBorder(context));

    List<Widget> _children = [];
    final len = children.length;

    for (var i = 0; i < len; i++) {
      _children.add(children[i]);

      if (i < len - 1) {
        double pad = 15;
        if (children[i + 1].runtimeType.toString() == 'ConfigButtonItem') {
          pad = 0;
        }
        _children.add(Padding(
            child: Divider(height: 1, color: Utils.configSectionBorder(context)), padding: EdgeInsets.only(left: pad)));
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      label != null ? ConfigHeader(label: label, color: labelColor) : Container(height: 20),
      Container(
          decoration:
              BoxDecoration(border: Border(top: border, bottom: border), color: Utils.configItemBackground(context)),
          child: Column(
            children: _children,
          ))
    ]);
  }
}
