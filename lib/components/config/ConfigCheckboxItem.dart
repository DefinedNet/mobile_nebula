import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile_nebula/components/SpecialButton.dart';
import 'package:mobile_nebula/services/utils.dart';

class ConfigCheckboxItem extends StatelessWidget {
  const ConfigCheckboxItem({Key key, this.label, this.content, this.labelWidth = 100, this.onChanged, this.checked})
      : super(key: key);

  final Widget label;
  final Widget content;
  final double labelWidth;
  final bool checked;
  final Function onChanged;

  @override
  Widget build(BuildContext context) {
    Widget item = Container(
        padding: EdgeInsets.only(left: 15),
        constraints: BoxConstraints(minHeight: Utils.minInteractiveSize, minWidth: double.infinity),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            label != null ? Container(width: labelWidth, child: label) : Container(),
            Expanded(child: Container(child: content, padding: EdgeInsets.only(right: 10))),
            checked
                ? Icon(CupertinoIcons.check_mark, color: CupertinoColors.systemBlue.resolveFrom(context), size: 34)
                : Container()
          ],
        ));

    if (onChanged != null) {
      return SpecialButton(
        color: Utils.configItemBackground(context),
        child: item,
        onPressed: () {
          if (onChanged != null) {
            onChanged();
          }
        },
      );
    } else {
      return item;
    }
  }
}
