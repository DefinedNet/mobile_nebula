import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile_nebula/components/config/config_checkbox_item.dart';
import 'package:mobile_nebula/components/config/config_item.dart';
import 'package:mobile_nebula/components/config/config_page_item.dart';
import 'package:mobile_nebula/components/config/config_section.dart';
import 'package:mobile_nebula/components/danger_button.dart';
import 'package:mobile_nebula/components/simple_page.dart';
import 'package:mobile_nebula/models/certificate.dart';
import 'package:mobile_nebula/models/hostinfo.dart';
import 'package:mobile_nebula/models/site.dart';
import 'package:mobile_nebula/screens/siteConfig/certificate_details_screen.dart';
import 'package:mobile_nebula/services/utils.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class HostInfoScreen extends StatefulWidget {
  const HostInfoScreen({
    super.key,
    required this.hostInfo,
    required this.isLighthouse,
    required this.pending,
    this.onChanged,
    required this.site,
    required this.supportsQRScanning,
  });

  final bool isLighthouse;
  final bool pending;
  final HostInfo hostInfo;
  final Function? onChanged;
  final Site site;

  final bool supportsQRScanning;

  @override
  HostInfoScreenState createState() => HostInfoScreenState();
}

//TODO: have a config option to refresh hostmaps on a cadence (applies to 3 screens so far)

class HostInfoScreenState extends State<HostInfoScreen> {
  late HostInfo hostInfo;
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
      title: Text('$title Host Info'),
      refreshController: refreshController,
      onRefresh: () async {
        await _getHostInfo();
        refreshController.refreshCompleted();
      },
      child: Column(
        children: [_buildMain(), _buildDetails(), _buildRemotes(), !widget.pending ? _buildClose() : Container()],
      ),
    );
  }

  Widget _buildMain() {
    return ConfigSection(
      children: [
        ConfigItem(
          label: Text('VPN Addresses'),
          labelWidth: 150,
          crossAxisAlignment: CrossAxisAlignment.start,
          content: SelectableText(hostInfo.vpnAddrs.join('\n')),
        ),
        hostInfo.cert != null
            ? ConfigPageItem(
              label: Text('Certificate'),
              labelWidth: 150,
              content: Text(hostInfo.cert!.name),
              onPressed:
                  () => Utils.openPage(
                    context,
                    (context) => CertificateDetailsScreen(
                      certInfo: CertificateInfo(cert: hostInfo.cert!),
                      supportsQRScanning: widget.supportsQRScanning,
                    ),
                  ),
            )
            : Container(),
      ],
    );
  }

  Widget _buildDetails() {
    return ConfigSection(
      children: <Widget>[
        ConfigItem(
          label: Text('Lighthouse'),
          labelWidth: 150,
          content: SelectableText(widget.isLighthouse ? 'Yes' : 'No'),
        ),
        ConfigItem(label: Text('Local Index'), labelWidth: 150, content: SelectableText('${hostInfo.localIndex}')),
        ConfigItem(label: Text('Remote Index'), labelWidth: 150, content: SelectableText('${hostInfo.remoteIndex}')),
        ConfigItem(
          label: Text('Message Counter'),
          labelWidth: 150,
          content: SelectableText('${hostInfo.messageCounter}'),
        ),
      ],
    );
  }

  Widget _buildRemotes() {
    if (hostInfo.remoteAddresses.isEmpty) {
      return ConfigSection(
        label: 'REMOTES',
        children: [ConfigItem(content: Text('No remote addresses yet'), labelWidth: 0)],
      );
    }

    return widget.pending ? _buildStaticRemotes() : _buildEditRemotes();
  }

  Widget _buildEditRemotes() {
    List<Widget> items = [];
    final currentRemote = hostInfo.currentRemote.toString();
    final double ipWidth =
        Utils.textSize("000.000.000.000:000000", CupertinoTheme.of(context).textTheme.textStyle).width;

    for (var remoteObj in hostInfo.remoteAddresses) {
      String remote = remoteObj.toString();
      items.add(
        ConfigCheckboxItem(
          key: Key(remote),
          label: Text(remote), //TODO: need to do something to adjust the font size in the event we have an ipv6 address
          labelWidth: ipWidth,
          checked: currentRemote == remote,
          onChanged: () async {
            if (remote == currentRemote) {
              return;
            }

            try {
              final h = await widget.site.setRemoteForTunnel(hostInfo.vpnAddrs[0], remote);
              if (h != null) {
                _setHostInfo(h);
              }
            } catch (err) {
              Utils.popError('Error while changing the remote', err.toString());
            }
          },
        ),
      );
    }

    return ConfigSection(label: items.isNotEmpty ? 'Tap to change the active address' : null, children: items);
  }

  Widget _buildStaticRemotes() {
    List<Widget> items = [];
    final currentRemote = hostInfo.currentRemote.toString();
    final double ipWidth =
        Utils.textSize("000.000.000.000:000000", CupertinoTheme.of(context).textTheme.textStyle).width;

    for (var remoteObj in hostInfo.remoteAddresses) {
      String remote = remoteObj.toString();
      items.add(
        ConfigCheckboxItem(
          key: Key(remote),
          label: Text(remote), //TODO: need to do something to adjust the font size in the event we have an ipv6 address
          labelWidth: ipWidth,
          checked: currentRemote == remote,
        ),
      );
    }

    return ConfigSection(label: items.isNotEmpty ? 'REMOTES' : null, children: items);
  }

  Widget _buildClose() {
    final outerContext = context;
    return Padding(
      padding: EdgeInsets.only(top: 50, bottom: 10, left: 10, right: 10),
      child: SizedBox(
        width: double.infinity,
        child: DangerButton(
          child: Text('Close Tunnel'),
          onPressed:
              () => Utils.confirmDelete(outerContext, 'Close Tunnel?', () async {
                try {
                  await widget.site.closeTunnel(hostInfo.vpnAddrs[0]);
                  if (widget.onChanged != null) {
                    widget.onChanged!();
                  }
                  if (outerContext.mounted) {
                    Navigator.pop(outerContext);
                  }
                } catch (err) {
                  Utils.popError('Error while trying to close the tunnel', err.toString());
                }
              }, deleteLabel: 'Close'),
        ),
      ),
    );
  }

  Future<dynamic> _getHostInfo() async {
    try {
      final h = await widget.site.getHostInfo(hostInfo.vpnAddrs[0], widget.pending);
      if (h == null) {
        return Utils.popError('', 'The tunnel for this host no longer exists');
      }

      _setHostInfo(h);
    } catch (err) {
      Utils.popError('Failed to refresh host info', err.toString());
    }
  }

  void _setHostInfo(HostInfo h) {
    h.remoteAddresses.sort((a, b) {
      final diff = a.ip.compareTo(b.ip);
      return diff == 0 ? a.port - b.port : diff;
    });

    setState(() {
      hostInfo = h;
    });
  }
}
