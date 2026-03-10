import 'package:flutter/material.dart';

const double _headerFontSize = 13.0;

class ConfigHeader extends StatelessWidget {
  const ConfigHeader({super.key, required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 10.0, top: 30.0, bottom: 5.0, right: 10.0),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium!.copyWith(
          color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: _headerFontSize,
        ),
      ),
    );
  }
}
