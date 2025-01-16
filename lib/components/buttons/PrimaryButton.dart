import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({Key? key, required this.child, this.onPressed}) : super(key: key);

  final Widget child;
  final GestureTapCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) {
      return FilledButton(
          onPressed: onPressed,
          child: child,
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary));
    } else {
      // Workaround for https://github.com/flutter/flutter/issues/161590
      final themeData = CupertinoTheme.of(context);
      return CupertinoTheme(
          data: themeData.copyWith(primaryColor: CupertinoColors.white),
          child: CupertinoButton(
              child: child, onPressed: onPressed, color: CupertinoColors.secondaryLabel.resolveFrom(context)));
    }
  }
}
