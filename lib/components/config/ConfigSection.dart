import 'package:flutter/material.dart';
import 'package:mobile_nebula/services/utils.dart';

import 'ConfigHeader.dart';

class ConfigSection extends StatelessWidget {
  const ConfigSection({super.key, this.label, required this.children, this.borderColor, this.labelColor, this.padding});

  final List<Widget> children;
  final String? label;
  final Color? borderColor;
  final Color? labelColor;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final border = BorderSide(color: borderColor ?? Utils.configSectionBorder(context));

    List<Widget> mappedChildren = [];
    final len = children.length;

    for (var i = 0; i < len; i++) {
      mappedChildren.add(children[i]);

      if (i < len - 1) {
        double pad = 15;
        if (children[i + 1].runtimeType.toString() == 'ConfigButtonItem') {
          pad = 0;
        }
        mappedChildren.add(
          Padding(
            padding: EdgeInsets.only(left: pad, right: pad),
            child: Divider(height: 1, color: Utils.configSectionBorder(context)),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label != null ? ConfigHeader(label: label!, color: labelColor) : Container(height: 10),
        Container(
          decoration: BoxDecoration(
            border: Border(top: border, bottom: border),
            color: Utils.configItemBackground(context),
          ),
          padding: padding,
          child: Column(children: mappedChildren),
        ),
      ],
    );
  }
}
