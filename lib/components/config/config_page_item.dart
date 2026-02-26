import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile_nebula/components/special_button.dart';
import 'package:mobile_nebula/services/utils.dart';

const defaultPadding = EdgeInsets.symmetric(vertical: 6, horizontal: 15);

class ConfigPageItem extends StatelessWidget {
  const ConfigPageItem({
    super.key,
    this.label,
    this.content,
    this.labelWidth = 100,
    this.onPressed,
    this.disabled = false,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.padding = defaultPadding,
  });

  final Widget? label;
  final Widget? content;
  final double labelWidth;
  final CrossAxisAlignment crossAxisAlignment;
  final void Function()? onPressed;
  final bool disabled;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelLarge!.copyWith(
      fontWeight: FontWeight.normal,
      color: Theme.of(context).colorScheme.onSecondaryContainer,
    );

    return SpecialButton(
      onPressed: disabled ? null : onPressed,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Container(
        padding: padding,
        constraints: BoxConstraints(minHeight: Utils.minInteractiveSize, minWidth: double.infinity),
        child: Row(
          crossAxisAlignment: crossAxisAlignment,
          children: <Widget>[
            label != null
                ? SizedBox(
                    width: labelWidth,
                    child: DefaultTextStyle(style: textStyle, child: label!),
                  )
                : Container(),
            Expanded(
              child: Container(padding: EdgeInsets.only(right: 10), child: content),
            ),
            disabled
                ? Container()
                : Icon(Icons.arrow_forward_ios, color: CupertinoColors.placeholderText.resolveFrom(context), size: 18),
          ],
        ),
      ),
    );
  }
}
