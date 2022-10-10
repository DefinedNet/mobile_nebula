import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mobile_nebula/components/SpecialButton.dart';
import 'package:mobile_nebula/models/Site.dart';
import 'package:mobile_nebula/services/utils.dart';

class SiteItem extends StatelessWidget {
  const SiteItem({Key? key, required this.site, this.onPressed}) : super(key: key);

  final Site site;
  final onPressed;

  @override
  Widget build(BuildContext context) {
    final borderColor = site.errors.length > 0
        ? CupertinoColors.systemRed.resolveFrom(context)
        : site.connected
            ? CupertinoColors.systemGreen.resolveFrom(context)
            : CupertinoColors.systemGrey2.resolveFrom(context);
    final border = BorderSide(color: borderColor, width: 10);

    return Container(
        margin: EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(border: Border(left: border)),
        child: _buildContent(context));
  }

  Widget _buildContent(BuildContext context) {
    final border = BorderSide(color: Utils.configSectionBorder(context));
    final dnIcon = Theme.of(context).brightness == Brightness.dark ? 'images/dn-logo-dark.svg' : 'images/dn-logo-light.svg';

    return SpecialButton(
        decoration:
            BoxDecoration(border: Border(top: border, bottom: border), color: Utils.configItemBackground(context)),
        onPressed: onPressed,
        child: Padding(
            padding: EdgeInsets.fromLTRB(10, 10, 5, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                site.managed ?
                  Padding(padding: EdgeInsets.only(right: 10), child: SvgPicture.asset(dnIcon, width: 12)) :
                  Container(),
                Expanded(child: Text(site.name, style: TextStyle(fontWeight: FontWeight.bold))),
                Padding(padding: EdgeInsets.only(right: 10)),
                Icon(CupertinoIcons.forward, color: CupertinoColors.placeholderText.resolveFrom(context), size: 18)
              ],
            )));
  }
}
