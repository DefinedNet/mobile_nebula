import 'package:flutter/material.dart';
import 'package:mobile_nebula/services/utils.dart';

const defaultPadding = EdgeInsets.symmetric(vertical: 6, horizontal: 15);

class ConfigItem extends StatelessWidget {
  const ConfigItem({
    super.key,
    this.label,
    required this.content,
    this.labelWidth = 100,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.padding = defaultPadding,
  });

  final Widget? label;
  final Widget content;
  final double labelWidth;
  final CrossAxisAlignment crossAxisAlignment;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelLarge!.copyWith(
      fontWeight: FontWeight.normal,
      color: Theme.of(context).colorScheme.onSecondaryContainer,
    );

    return Container(
      color: Theme.of(context).colorScheme.primaryContainer,
      padding: padding,
      constraints: BoxConstraints(minHeight: Utils.minInteractiveSize),
      child: Row(
        crossAxisAlignment: crossAxisAlignment,
        children: <Widget>[
          SizedBox(
            width: labelWidth,
            child: DefaultTextStyle(
              style: textStyle,
              child: Container(child: label),
            ),
          ),
          Expanded(
            child: DefaultTextStyle(
              style: textStyle,
              child: Container(child: content),
            ),
          ),
        ],
      ),
    );
  }
}
