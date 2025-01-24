import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../models/Site.dart';

class SiteTitle extends StatelessWidget {
  const SiteTitle({Key? key, required this.site}) : super(key: key);

  final Site site;

  @override
  Widget build(BuildContext context) {
    final dnIcon =
        Theme.of(context).brightness == Brightness.dark ? 'images/dn-logo-dark.svg' : 'images/dn-logo-light.svg';

    return IntrinsicWidth(
        child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              site.managed
                  ? Padding(padding: EdgeInsets.only(right: 10), child: SvgPicture.asset(dnIcon, width: 12))
                  : Container(),
              Expanded(
                  child: Text(
                site.name,
                overflow: TextOverflow.ellipsis,
              ))
            ])));
  }
}
