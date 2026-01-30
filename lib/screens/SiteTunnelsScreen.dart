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
    final List<ConfigPageItem> children =
        tunnels.map((hostInfo) {
          final isLh = _isLighthouse(hostInfo.vpnAddrs);
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
            content: Container(
              alignment: Alignment.centerLeft,
              child: Row(
                children: <Widget>[
                  Padding(padding: EdgeInsets.only(right: 10), child: icon),
                  Text(hostInfo.cert?.name ?? hostInfo.vpnAddrs[0]),
                ],
              ),
            ),
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
      final aLh = _isLighthouse(a.vpnAddrs), bLh = _isLighthouse(b.vpnAddrs);

      if (aLh && !bLh) {
        return -1;
      } else if (!aLh && bLh) {
        return 1;
      }

      final aName = a.cert?.name ?? "";
      final bName = b.cert?.name ?? "";
      final name = aName.compareTo(bName);
      if (name != 0) {
        return name;
      }

      return a.vpnAddrs[0].compareTo(b.vpnAddrs[0]);
    });
  }

  bool _isLighthouse(List<String> vpnAddrs) {
    var isLh = false;
    for (var vpnAddr in vpnAddrs) {
      if (site.staticHostmap[vpnAddr]?.lighthouse ?? false) {
        isLh = true;
        break;
      }
    }
    return isLh;
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
      Utils.popError('Error while fetching hostmap', err.toString());
    }
  }
}
