import 'package:flutter/material.dart';
import 'package:mobile_nebula/models/Site.dart';
import 'package:mobile_nebula/services/utils.dart';

import 'config/ConfigItem.dart';
import 'config/ConfigPageItem.dart';
import 'config/ConfigSection.dart';

class SiteItem extends StatelessWidget {
  const SiteItem({super.key, required this.site, this.onPressed});

  final Site site;
  final void Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    return _buildContent(context);
  }

  Widget _siteNameWidget(context) {
    var badgeTheme = Theme.of(context).badgeTheme;
    Widget nameWidget = Text(site.name, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16));

    Widget managedBadge;
    if (site.managed) {
      managedBadge = Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: badgeTheme.backgroundColor),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text('Managed', style: badgeTheme.textStyle),
        ),
      );

      nameWidget = Container(margin: EdgeInsets.only(right: 10), child: nameWidget);
    } else {
      managedBadge = Text('');
    }

    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(alignment: PlaceholderAlignment.middle, child: nameWidget),
          WidgetSpan(alignment: PlaceholderAlignment.middle, child: managedBadge),
        ],
      ),
    );
  }

  Widget _siteStatusWidget(context) {
    final grayTextColor = Theme.of(context).colorScheme.onSecondaryContainer;
    var fontStyle = TextStyle(color: grayTextColor, fontSize: 14, fontWeight: FontWeight.w500);
    if (site.errors.isNotEmpty) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.warning_rounded, size: 16, color: grayTextColor),
          Text(' '),
          Text('Resolve errors', style: fontStyle),
        ],
      );
    }

    return Text(site.status, style: fontStyle);
  }

  Widget _buildContent(BuildContext context) {
    void handleChange(v) async {
      try {
        if (v) {
          await site.start();
        } else {
          await site.stop();
        }
      } catch (error) {
        var action = v ? 'start' : 'stop';
        Utils.popError('Failed to $action the site', error.toString());
      }
    }

    final grayTextColor = Theme.of(context).colorScheme.onSecondaryContainer;

    return ConfigSection(
      children: <Widget>[
        ConfigItem(
          labelWidth: 0,
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_siteNameWidget(context), Container(height: 4), _siteStatusWidget(context)],
                ),
              ),
              Switch.adaptive(
                value: site.connected,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: site.errors.isNotEmpty && !site.connected ? null : handleChange,
              ),
            ],
          ),
        ),
        ConfigPageItem(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
          label: Text('Details', style: TextStyle(color: grayTextColor, fontSize: 14, fontWeight: FontWeight.w500)),
          onPressed: onPressed,
        ),
      ],
    );
  }
}
