import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile_nebula/components/SimplePage.dart';
import 'package:mobile_nebula/components/config/ConfigPageItem.dart';
import 'package:mobile_nebula/components/config/ConfigSection.dart';
import 'package:mobile_nebula/models/HostInfo.dart';
import 'package:mobile_nebula/models/Site.dart';
import 'package:mobile_nebula/screens/HostInfoScreen.dart';
import 'package:mobile_nebula/services/utils.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class SiteTunnelsScreen extends StatefulWidget {
  const SiteTunnelsScreen({
    super.key,
    required this.site,
    required this.tunnels,
    required this.pending,
    required this.onChanged,
    required this.supportsQRScanning,
  });

  final Site site;
  final List<HostInfo> tunnels;
  final bool pending;
  final Function(List<HostInfo>)? onChanged;

  final bool supportsQRScanning;

  @override
  _SiteTunnelsScreenState createState() => _SiteTunnelsScreenState();
}

class _SiteTunnelsScreenState extends State<SiteTunnelsScreen> {
  late Site site;
  late List<HostInfo> tunnels;
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
    refreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double ipWidth = Utils.textSize("000.000.000.000", CupertinoTheme.of(context).textTheme.textStyle).width + 32;

    final List<ConfigPageItem> children =
        tunnels.map((hostInfo) {
          final isLh = site.staticHostmap[hostInfo.vpnIp]?.lighthouse ?? false;
          final icon = switch (isLh) {
            true => Icon(Icons.lightbulb_outline, color: CupertinoColors.placeholderText.resolveFrom(context)),
            false => Icon(Icons.computer, color: CupertinoColors.placeholderText.resolveFrom(context)),
          };

          return (ConfigPageItem(
            onPressed:
                () => Utils.openPage(
                  context,
                  (context) => HostInfoScreen(
                    isLighthouse: isLh,
                    hostInfo: hostInfo,
                    pending: widget.pending,
                    site: widget.site,
                    onChanged: () {
                      _listHostmap();
                    },
                    supportsQRScanning: widget.supportsQRScanning,
                  ),
                ),
            label: Row(
              children: <Widget>[Padding(padding: EdgeInsets.only(right: 10), child: icon), Text(hostInfo.vpnIp)],
            ),
            labelWidth: ipWidth,
            content: Container(alignment: Alignment.centerRight, child: Text(hostInfo.cert?.details.name ?? "")),
          ));
        }).toList();

    final Widget child = switch (children.length) {
      0 => Center(child: Padding(padding: EdgeInsets.only(top: 30), child: Text('No tunnels to show'))),
      _ => ConfigSection(children: children),
    };

    final title = widget.pending ? 'Pending' : 'Active';

    return SimplePage(
      title: Text('$title Tunnels'),
      refreshController: refreshController,
      onRefresh: () async {
        await _listHostmap();
        refreshController.refreshCompleted();
      },
      child: child,
    );
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
        widget.onChanged!(tunnels);
      }
      setState(() {});
    } catch (err) {
      Utils.popError(context, 'Error while fetching hostmap', err.toString());
    }
  }
}
