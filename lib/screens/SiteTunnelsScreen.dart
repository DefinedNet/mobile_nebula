import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_nebula/components/SimplePage.dart';
import 'package:mobile_nebula/components/config/ConfigPageItem.dart';
import 'package:mobile_nebula/components/config/ConfigSection.dart';
import 'package:mobile_nebula/models/HostInfo.dart';
import 'package:mobile_nebula/models/Site.dart';
import 'package:mobile_nebula/screens/HostInfoScreen.dart';
import 'package:mobile_nebula/services/utils.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class SiteTunnelsScreen extends StatefulWidget {
  const SiteTunnelsScreen({Key key, this.site, this.tunnels, this.pending, this.onChanged}) : super(key: key);

  final Site site;
  final List<HostInfo> tunnels;
  final bool pending;
  final Function(List<HostInfo>) onChanged;

  @override
  _SiteTunnelsScreenState createState() => _SiteTunnelsScreenState();
}

class _SiteTunnelsScreenState extends State<SiteTunnelsScreen> {
  Site site;
  List<HostInfo> tunnels;
  RefreshController refreshController = RefreshController(initialRefresh: false);

  @override
  void initState() {
    site = widget.site;
    tunnels = widget.tunnels;
    _sortTunnels();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double ipWidth = Utils.textSize("000.000.000.000", CupertinoTheme.of(context).textTheme.textStyle).width + 32;

    List<Widget> children = [];
    tunnels.forEach((hostInfo) {
      Widget icon;

      final isLh = site.staticHostmap[hostInfo.vpnIp]?.lighthouse ?? false;
      if (isLh) {
        icon = Icon(Icons.lightbulb_outline, color: CupertinoColors.placeholderText.resolveFrom(context));
      } else {
        icon = Icon(Icons.computer, color: CupertinoColors.placeholderText.resolveFrom(context));
      }

      children.add(ConfigPageItem(
        onPressed: () => Utils.openPage(
            context,
            (context) => HostInfoScreen(
                isLighthouse: isLh,
                hostInfo: hostInfo,
                pending: widget.pending,
                site: widget.site,
                onChanged: () {
                  _listHostmap();
                })),
        label: Row(children: <Widget>[Padding(child: icon, padding: EdgeInsets.only(right: 10)), Text(hostInfo.vpnIp)]),
        labelWidth: ipWidth,
        content: Container(alignment: Alignment.centerRight, child: Text(hostInfo.cert?.details?.name ?? "")),
      ));
    });

    Widget child;
    if (children.length == 0) {
      child = Center(child: Padding(child: Text('No tunnels to show'), padding: EdgeInsets.only(top: 30)));
    } else {
      child = ConfigSection(children: children);
    }

    final title = widget.pending ? 'Pending' : 'Active';

    return SimplePage(
        title: "$title Tunnels",
        leadingAction: Utils.leadingBackWidget(context, onPressed: () {
          Navigator.pop(context);
        }),
        refreshController: refreshController,
        onRefresh: () async {
          await _listHostmap();
          refreshController.refreshCompleted();
        },
        child: child);
  }

  _sortTunnels() {
    tunnels.sort((a, b) {
      final aLh = _isLighthouse(a.vpnIp), bLh = _isLighthouse(b.vpnIp);

      if (aLh && !bLh) {
        return -1;
      } else if (!aLh && bLh) {
        return 1;
      }

      return Utils.ip2int(a.vpnIp) - Utils.ip2int(b.vpnIp);
    });
  }

  bool _isLighthouse(String vpnIp) {
    return site.staticHostmap[vpnIp]?.lighthouse ?? false;
  }

  _listHostmap() async {
    try {
      if (widget.pending) {
        tunnels = await site.listPendingHostmap();
      } else {
        tunnels = await site.listHostmap();
      }

      _sortTunnels();
      if (widget.onChanged != null) {
        widget.onChanged(tunnels);
      }
      setState(() {});
    } catch (err) {
      Utils.popError(context, 'Error while fetching hostmap', err);
    }
  }
}
