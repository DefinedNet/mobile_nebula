import 'package:flutter/material.dart';
import 'package:mobile_nebula/models/site.dart';
import 'package:mobile_nebula/services/utils.dart';

import 'config/config_item.dart';
import 'config/config_page_item.dart';
import 'config/config_section.dart';

class SiteItem extends StatefulWidget {
  const SiteItem({super.key, required this.site, this.onPressed});

  final Site site;
  final void Function()? onPressed;

  @override
  State<SiteItem> createState() => _SiteItemState();
}

class _SiteItemState extends State<SiteItem> {
  @override
  Widget build(BuildContext context) {
    return _buildContent(context);
  }

  Widget _siteNameWidget(BuildContext context) {
    final badgeTheme = Theme.of(context).badgeTheme;
    final nameStyle = TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 16,
      height: 1.6,
      color: Theme.of(context).textTheme.bodyLarge?.color,
    );
    List<InlineSpan> children = [];

    // Add the name
    children.add(TextSpan(text: widget.site.name, style: nameStyle));

    if (widget.site.managed) {
      // Toss some space in
      children.add(TextSpan(text: '  ', style: nameStyle));

      // Add the managed badge
      children.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: badgeTheme.backgroundColor),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text('Managed', style: badgeTheme.textStyle),
            ),
          ),
        ),
      );
    }

    return Text.rich(TextSpan(children: children));
  }

  Widget _siteStatusWidget(BuildContext context) {
    final grayTextColor = Theme.of(context).colorScheme.onSecondaryContainer;
    var fontStyle = TextStyle(color: grayTextColor, fontSize: 14, fontWeight: FontWeight.w500);
    if (widget.site.errors.isNotEmpty) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.warning_rounded, size: 16, color: grayTextColor),
          Text(' '),
          Text('Resolve errors', style: fontStyle),
        ],
      );
    }

    return Text(widget.site.status, style: fontStyle);
  }

  Widget _buildContent(BuildContext context) {
    final grayTextColor = Theme.of(context).colorScheme.onSecondaryContainer;

    List<Widget> children = [];
    children.add(
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
              value: widget.site.connected,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: widget.site.errors.isNotEmpty && !widget.site.connected ? null : toggleSite,
            ),
          ],
        ),
      ),
    );

    children.add(
      ConfigPageItem(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
        label: Text(
          'Details',
          style: TextStyle(color: grayTextColor, fontSize: 14, fontWeight: FontWeight.w500),
        ),
        onPressed: widget.onPressed,
      ),
    );

    return ConfigSection(children: children);
  }

  void toggleSite(bool val) async {
    try {
      if (val) {
        await widget.site.start();
      } else {
        await widget.site.stop();
      }
      setState(() {});
    } catch (error) {
      var action = val ? 'start' : 'stop';
      Utils.popError('Failed to $action the site', error.toString());
    }
  }
}
