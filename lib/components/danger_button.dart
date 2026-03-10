import 'package:flutter/material.dart';

class DangerButton extends StatelessWidget {
  const DangerButton({super.key, required this.child, this.onPressed});

  final Widget child;
  final GestureTapCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.error,
        foregroundColor: Theme.of(context).colorScheme.onError,
      ),
      child: child,
    );
  }
}
