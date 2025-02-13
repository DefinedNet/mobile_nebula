import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:mobile_nebula/components/SimplePage.dart';
import 'package:mobile_nebula/components/config/ConfigPageItem.dart';
import 'package:mobile_nebula/components/config/ConfigItem.dart';
import 'package:mobile_nebula/components/config/ConfigSection.dart';
import 'package:mobile_nebula/models/HostInfo.dart';
import 'package:mobile_nebula/models/Site.dart';
import 'package:mobile_nebula/screens/SiteLogsScreen.dart';
import 'package:mobile_nebula/screens/SiteTunnelsScreen.dart';
import 'package:mobile_nebula/screens/siteConfig/SiteConfigScreen.dart';
import 'package:mobile_nebula/services/utils.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../components/DangerButton.dart';
import '../components/SiteTitle.dart';

//TODO: If the site isn't active, don't respond to reloads on hostmaps
//TODO: ios is now the problem with connecting screwing our ability to query the hostmap (its a race)

class SiteDetailScreen extends StatefulWidget {
  const SiteDetailScreen({super.key, required this.site, this.onChanged, required this.supportsQRScanning});

  final Site site;
  final Function? onChanged;
  final bool supportsQRScanning;

  @override
  _SiteDetailScreenState createState() => _SiteDetailScreenState();
}

class _SiteDetailScreenState extends State<SiteDetailScreen> {
  late Site site;
  late StreamSubscription onChange;
  static const platform = MethodChannel('net.defined.mobileNebula/NebulaVpnService');
  bool changed = false;
  List<HostInfo>? activeHosts;
  List<HostInfo>? pendingHosts;
  RefreshController refreshController = RefreshController(initialRefresh: false);

  @override
  void initState() {
    site = widget.site;
    if (site.connected) {
      _listHostmap();
    }

    onChange = site.onChange().listen(
      (_) {
        // TODO: Gross hack... we get site.connected = true to trigger the toggle before the VPN service has started.
        // If we fetch the hostmap now we'll never get a response. Wait until Nebula is running.
        if (site.status == 'Connected') {
          _listHostmap();
        } else {
          activeHosts = null;
          pendingHosts = null;
        }

        setState(() {});
      },
      onError: (err) {
        setState(() {});
        Utils.popError(context, "Error", err);
      },
    );

    super.initState();
  }

  @override
  void dispose() {
    onChange.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = SiteTitle(site: widget.site);

    return SimplePage(
      title: title,
      leadingAction: Utils.leadingBackWidget(
        context,
        onPressed: () {
          if (changed && widget.onChanged != null) {
            widget.onChanged!();
          }
          Navigator.pop(context);
        },
      ),
      refreshController: refreshController,
      onRefresh: () async {
        if (site.connected && site.status == "Connected") {
          await _listHostmap();
        }
        refreshController.refreshCompleted();
      },
      child: Column(
        children: [
          _buildErrors(),
          _buildConfig(),
          site.connected ? _buildHosts() : Container(),
          _buildSiteDetails(),
          _buildDelete(),
        ],
      ),
    );
  }

  Widget _buildErrors() {
    if (site.errors.isEmpty) {
      return Container();
    }

    List<Widget> items = [];
    site.errors.forEach((error) {
      items.add(
        ConfigItem(
          labelWidth: 0,
          content: Padding(padding: EdgeInsets.symmetric(vertical: 10), child: SelectableText(error)),
        ),
      );
    });

    return ConfigSection(
      label: 'ERRORS',
      borderColor: CupertinoColors.systemRed.resolveFrom(context),
      labelColor: CupertinoColors.systemRed.resolveFrom(context),
      children: items,
    );
  }

  Widget _buildConfig() {
    void handleChange(v) async {
      try {
        if (v) {
          await widget.site.start();
        } else {
          await widget.site.stop();
        }
      } catch (error) {
        var action = v ? 'start' : 'stop';
        Utils.popError(context, 'Failed to $action the site', error.toString());
      }
    }

    return ConfigSection(
      children: <Widget>[
        ConfigItem(
          label: Text('Status'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.only(right: 5),
                child: Text(
                  widget.site.status,
                  style: TextStyle(color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                ),
              ),
              Switch.adaptive(
                value: widget.site.connected,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: widget.site.errors.isNotEmpty && !widget.site.connected ? null : handleChange,
              ),
            ],
          ),
        ),
        ConfigPageItem(
          label: Text('Logs'),
          onPressed: () {
            Utils.openPage(context, (context) {
              return SiteLogsScreen(site: widget.site);
            });
          },
        ),
      ],
    );
  }

  Widget _buildHosts() {
    Widget active, pending;

    if (activeHosts == null) {
      active = SizedBox(height: 20, width: 20, child: PlatformCircularProgressIndicator());
    } else {
      active = Text(Utils.itemCountFormat(activeHosts!.length, singleSuffix: "tunnel", multiSuffix: "tunnels"));
    }

    if (pendingHosts == null) {
      pending = SizedBox(height: 20, width: 20, child: PlatformCircularProgressIndicator());
    } else {
      pending = Text(Utils.itemCountFormat(pendingHosts!.length, singleSuffix: "tunnel", multiSuffix: "tunnels"));
    }

    return ConfigSection(
      label: "TUNNELS",
      children: <Widget>[
        ConfigPageItem(
          onPressed: () {
            if (activeHosts == null) return;

            Utils.openPage(
              context,
              (context) => SiteTunnelsScreen(
                pending: false,
                tunnels: activeHosts!,
                site: site,
                onChanged: (hosts) {
                  setState(() {
                    activeHosts = hosts;
                  });
                },
                supportsQRScanning: widget.supportsQRScanning,
              ),
            );
          },
          label: Text("Active"),
          content: Container(alignment: Alignment.centerRight, child: active),
        ),
        ConfigPageItem(
          onPressed: () {
            if (pendingHosts == null) return;

            Utils.openPage(
              context,
              (context) => SiteTunnelsScreen(
                pending: true,
                tunnels: pendingHosts!,
                site: site,
                onChanged: (hosts) {
                  setState(() {
                    pendingHosts = hosts;
                  });
                },
                supportsQRScanning: widget.supportsQRScanning,
              ),
            );
          },
          label: Text("Pending"),
          content: Container(alignment: Alignment.centerRight, child: pending),
        ),
      ],
    );
  }

  Widget _buildSiteDetails() {
    return ConfigSection(
      children: <Widget>[
        ConfigPageItem(
          crossAxisAlignment: CrossAxisAlignment.center,
          content: Text('Configuration'),
          onPressed: () {
            Utils.openPage(context, (context) {
              return SiteConfigScreen(
                site: widget.site,
                onSave: (site) async {
                  changed = true;
                  setState(() {});
                },
                supportsQRScanning: widget.supportsQRScanning,
              );
            });
          },
        ),
      ],
    );
  }

  Widget _buildDelete() {
    return Padding(
      padding: EdgeInsets.only(top: 50, bottom: 10, left: 10, right: 10),
      child: SizedBox(
        width: double.infinity,
        child: DangerButton(
          child: Text('Delete'),
          onPressed:
              () => Utils.confirmDelete(context, 'Delete Site?', () async {
                if (await _deleteSite()) {
                  Navigator.of(context).pop();
                }
              }),
        ),
      ),
    );
  }

  _listHostmap() async {
    try {
      var maps = await site.listAllHostmaps();
      activeHosts = maps["active"];
      pendingHosts = maps["pending"];
      setState(() {});
    } catch (err) {
      Utils.popError(context, 'Error while fetching hostmaps', err.toString());
    }
  }

  Future<bool> _deleteSite() async {
    try {
      var err = await platform.invokeMethod("deleteSite", widget.site.id);
      if (err != null) {
        Utils.popError(context, 'Failed to delete the site', err);
        return false;
      }
    } catch (err) {
      Utils.popError(context, 'Failed to delete the site', err.toString());
      return false;
    }

    if (widget.onChanged != null) {
      widget.onChanged!();
    }
    return true;
  }
}
