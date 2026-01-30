import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile_nebula/components/SpecialButton.dart';
import 'package:mobile_nebula/services/utils.dart';

class ConfigCheckboxItem extends StatelessWidget {
  const ConfigCheckboxItem({
    super.key,
    this.label,
    this.content,
    this.labelWidth = 100,
    this.onChanged,
    this.checked = false,
  });

  final Widget? label;
  final Widget? content;
  final double labelWidth;
  final bool checked;
  final Function? onChanged;

  @override
  Widget build(BuildContext context) {
    Widget item = Container(
      padding: EdgeInsets.symmetric(horizontal: 15),
      constraints: BoxConstraints(minHeight: Utils.minInteractiveSize, minWidth: double.infinity),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          label != null ? SizedBox(width: labelWidth, child: label) : Container(),
          Expanded(child: Container(padding: EdgeInsets.only(right: 10), child: content)),
          checked
              ? Icon(CupertinoIcons.check_mark, color: CupertinoColors.systemBlue.resolveFrom(context))
              : Container(),
        ],
      ),
    );

    if (onChanged != null) {
      return SpecialButton(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: item,
        onPressed: () {
          if (onChanged != null) {
            onChanged!();
          }
        },
      );
    } else {
      return item;
    }
  }
}
