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
import 'package:duration/duration.dart';

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
  bool reauthSpin = false;
  List<HostInfo>? activeHosts;
  List<HostInfo>? pendingHosts;
  String expiresIn = "Unknown";
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

        setState(() {
          expiresIn = calcExpiresIn(site.managedOIDCExpiry);
        });
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
    final title = SiteTitle(site: site);

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
        //await Site.platform.invokeMethod('dn.doUpdate'); //todo?
        if (site.connected && site.status == "Connected") {
          await _listHostmap();
        }
        setState(() {
          expiresIn = calcExpiresIn(site.managedOIDCExpiry);
        });
        refreshController.refreshCompleted();
      },
      child: Column(
        children: [
          _buildErrors(),
          _buildConfig(),
          site.managed ? _buildManaged() : Container(),
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
    for (var error in site.errors) {
      items.add(
        ConfigItem(
          labelWidth: 0,
          content: Padding(padding: EdgeInsets.symmetric(vertical: 10), child: SelectableText(error)),
        ),
      );
    }
    //todo if expired, add reauth button
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
          await site.start();
        } else {
          await site.stop();
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
                  site.status,
                  style: TextStyle(color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                ),
              ),
              Switch.adaptive(
                value: site.connected,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: site.isSwitchOnAllowed() ? handleChange: null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String calcExpiresIn(DateTime? expiresAt) {
    if (expiresAt == null) {
      return "Never";
    }

    final exp = expiresAt.toLocal();
    if (exp.isBefore(DateTime.now())) {
      return "NOW";
    } else {
      final expAt = exp.difference(DateTime.now());
      return "in ${expAt.pretty(tersity: DurationTersity.second)}"; //todo minute?
    }
  }

  Widget _buildManaged() {
    if (site.managedOIDCEmail == null) {
      return Container();
    }

    var out = ConfigSection(
      label: "MANAGED CONFIG",
      children: <Widget>[],
    );

    expiresIn = calcExpiresIn(site.managedOIDCExpiry);

    Widget? reauthText = null;
    if (reauthSpin) {
      reauthText = SizedBox(height: 20, width: 20, child: PlatformCircularProgressIndicator());
    } else {
      reauthText = Text(expiresIn);
    }

    out.children.add(ConfigItem(
        label: Text("Username"),
        content: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[Text(site.managedOIDCEmail!)],
        )));
    out.children.add(ConfigPageItem(
        label: Text("Reauthenticate"),
        onPressed: _reauth,
        content: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[reauthText],
        )));

    return out;
  }

  Future<void> _reauth() async {
    setState(() {
      reauthSpin = true;
    });
    try {
      final loginUrl = await site.reauthenticate();
      await platform.invokeMethod("dn.popBrowser", loginUrl);
    } on PlatformException catch (err) {
      print(err);
    }
    setState(() {
      reauthSpin = false;
    });
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
                site: site,
                onSave: (site) async {
                  changed = true;
                  setState(() {});
                },
                supportsQRScanning: widget.supportsQRScanning,
              );
            });
          },
        ),
        ConfigPageItem(
          label: Text('Logs'),
          onPressed: () {
            Utils.openPage(context, (context) {
              return SiteLogsScreen(site: site);
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
      var err = await platform.invokeMethod("deleteSite", site.id);
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
