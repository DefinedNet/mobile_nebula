import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:mobile_nebula/components/SimplePage.dart';
import 'package:mobile_nebula/components/SpecialSelectableText.dart';
import 'package:mobile_nebula/components/config/ConfigCheckboxItem.dart';
import 'package:mobile_nebula/components/config/ConfigItem.dart';
import 'package:mobile_nebula/components/config/ConfigPageItem.dart';
import 'package:mobile_nebula/components/config/ConfigSection.dart';
import 'package:mobile_nebula/models/Certificate.dart';
import 'package:mobile_nebula/models/HostInfo.dart';
import 'package:mobile_nebula/models/Site.dart';
import 'package:mobile_nebula/screens/siteConfig/CertificateDetailsScreen.dart';
import 'package:mobile_nebula/services/utils.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class HostInfoScreen extends StatefulWidget {
  const HostInfoScreen({Key key, this.hostInfo, this.isLighthouse, this.pending, this.onChanged, this.site})
      : super(key: key);

  final bool isLighthouse;
  final bool pending;
  final HostInfo hostInfo;
  final Function onChanged;
  final Site site;

  @override
  _HostInfoScreenState createState() => _HostInfoScreenState();
}

//TODO: have a config option to refresh hostmaps on a cadence (applies to 3 screens so far)

class _HostInfoScreenState extends State<HostInfoScreen> {
  HostInfo hostInfo;
  RefreshController refreshController = RefreshController(initialRefresh: false);

  @override
  void initState() {
    _setHostInfo(widget.hostInfo);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.pending ? 'Pending' : 'Active';

    return SimplePage(
        title: '$title Host Info',
        refreshController: refreshController,
        onRefresh: () async {
          await _getHostInfo();
          refreshController.refreshCompleted();
        },
        leadingAction: Utils.leadingBackWidget(context, onPressed: () {
          Navigator.pop(context);
        }),
        child: Column(
            children: [_buildMain(), _buildDetails(), _buildRemotes(), !widget.pending ? _buildClose() : Container()]));
  }

  Widget _buildMain() {
    return ConfigSection(children: [
      ConfigItem(label: Text('VPN IP'), labelWidth: 150, content: SpecialSelectableText(hostInfo.vpnIp)),
      hostInfo.cert != null
          ? ConfigPageItem(
              label: Text('Certificate'),
              labelWidth: 150,
              content: Text(hostInfo.cert.details.name),
              onPressed: () => Utils.openPage(
                  context, (context) => CertificateDetailsScreen(certificate: CertificateInfo(cert: hostInfo.cert))))
          : Container(),
    ]);
  }

  Widget _buildDetails() {
    return ConfigSection(children: <Widget>[
      ConfigItem(
          label: Text('Lighthouse'),
          labelWidth: 150,
          content: SpecialSelectableText(widget.isLighthouse ? 'Yes' : 'No')),
      ConfigItem(label: Text('Local Index'), labelWidth: 150, content: SpecialSelectableText('${hostInfo.localIndex}')),
      ConfigItem(
          label: Text('Remote Index'), labelWidth: 150, content: SpecialSelectableText('${hostInfo.remoteIndex}')),
      ConfigItem(
          label: Text('Message Counter'),
          labelWidth: 150,
          content: SpecialSelectableText('${hostInfo.messageCounter}')),
      ConfigItem(
          label: Text('Cached Packets'), labelWidth: 150, content: SpecialSelectableText('${hostInfo.cachedPackets}')),
    ]);
  }

  Widget _buildRemotes() {
    if (hostInfo.remoteAddresses.length == 0) {
      return ConfigSection(
          label: 'REMOTES', children: [ConfigItem(content: Text('No remote addresses yet'), labelWidth: 0)]);
    }

    return widget.pending ? _buildStaticRemotes() : _buildEditRemotes();
  }

  Widget _buildEditRemotes() {
    List<Widget> items = [];
    final currentRemote = hostInfo.currentRemote.toString();
    final double ipWidth =
        Utils.textSize("000.000.000.000:000000", CupertinoTheme.of(context).textTheme.textStyle).width;

    hostInfo.remoteAddresses.forEach((remoteObj) {
      String remote = remoteObj.toString();
      items.add(ConfigCheckboxItem(
        key: Key(remote),
        label: Text(remote), //TODO: need to do something to adjust the font size in the event we have an ipv6 address
        labelWidth: ipWidth,
        checked: currentRemote == remote,
        onChanged: () async {
          if (remote == currentRemote) {
            return;
          }

          try {
            final h = await widget.site.setRemoteForTunnel(hostInfo.vpnIp, remote);
            if (h != null) {
              _setHostInfo(h);
            }
          } catch (err) {
            Utils.popError(context, 'Error while changing the remote', err);
          }
        },
      ));
    });

    return ConfigSection(label: items.length > 0 ? 'Tap to change the active address' : null, children: items);
  }

  Widget _buildStaticRemotes() {
    List<Widget> items = [];
    final currentRemote = hostInfo.currentRemote.toString();
    final double ipWidth =
        Utils.textSize("000.000.000.000:000000", CupertinoTheme.of(context).textTheme.textStyle).width;

    hostInfo.remoteAddresses.forEach((remoteObj) {
      String remote = remoteObj.toString();
      items.add(ConfigCheckboxItem(
        key: Key(remote),
        label: Text(remote), //TODO: need to do something to adjust the font size in the event we have an ipv6 address
        labelWidth: ipWidth,
        checked: currentRemote == remote,
      ));
    });

    return ConfigSection(label: items.length > 0 ? 'REMOTES' : null, children: items);
  }

  Widget _buildClose() {
    return Padding(
        padding: EdgeInsets.only(top: 50, bottom: 10, left: 10, right: 10),
        child: SizedBox(
            width: double.infinity,
            child: PlatformButton(
                child: Text('Close Tunnel'),
                color: CupertinoColors.systemRed.resolveFrom(context),
                onPressed: () => Utils.confirmDelete(context, 'Close Tunnel?', () async {
                  try {
                    await widget.site.closeTunnel(hostInfo.vpnIp);
                    if (widget.onChanged != null) {
                      widget.onChanged();
                    }
                    Navigator.pop(context);
                  } catch (err) {
                    Utils.popError(context, 'Error while trying to close the tunnel', err);
                  }
                }, deleteLabel: 'Close'))));
  }

  _getHostInfo() async {
    try {
      final h = await widget.site.getHostInfo(hostInfo.vpnIp, widget.pending);
      if (h == null) {
        return Utils.popError(context, '', 'The tunnel for this host no longer exists');
      }

      _setHostInfo(h);
    } catch (err) {
      Utils.popError(context, 'Failed to refresh host info', err);
    }
  }

  _setHostInfo(HostInfo h) {
    h.remoteAddresses.sort((a, b) {
      final diff = a.ip.compareTo(b.ip);
      return diff == 0 ? a.port - b.port : diff;
    });

    setState(() {
      hostInfo = h;
    });
  }
}
