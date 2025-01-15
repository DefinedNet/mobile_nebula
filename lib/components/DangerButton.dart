import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DangerButton extends StatelessWidget {
  const DangerButton({Key? key, required this.child, this.onPressed}) : super(key: key);

  final Widget child;
  final GestureTapCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) {
      return FilledButton(
          onPressed: onPressed,
          child: child,
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error));
    } else {
      return CupertinoButton(child: child, color: CupertinoColors.systemRed.resolveFrom(context), onPressed: onPressed);
    }
  }
}
