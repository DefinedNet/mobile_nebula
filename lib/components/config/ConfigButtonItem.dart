import 'package:flutter/material.dart';
import 'package:mobile_nebula/components/SpecialButton.dart';
import 'package:mobile_nebula/services/utils.dart';

// A config item that detects tapping and calls back on a tap
class ConfigButtonItem extends StatelessWidget {
  const ConfigButtonItem({super.key, this.content, this.onPressed});

  final Widget? content;
  final void Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    return SpecialButton(
      color: Theme.of(context).colorScheme.primaryContainer,
      onPressed: onPressed,
      useButtonTheme: true,
      child: Container(
        constraints: BoxConstraints(minHeight: Utils.minInteractiveSize, minWidth: double.infinity),
        child: Center(child: content),
      ),
    );
  }
}
