import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_nebula/components/FormPage.dart';
import 'package:mobile_nebula/components/PlatformTextFormField.dart';
import 'package:mobile_nebula/components/SpecialSelectableText.dart';
import 'package:mobile_nebula/components/config/ConfigPageItem.dart';
import 'package:mobile_nebula/components/config/ConfigItem.dart';
import 'package:mobile_nebula/components/config/ConfigSection.dart';
import 'package:mobile_nebula/models/Site.dart';
import 'package:mobile_nebula/screens/siteConfig/AdvancedScreen.dart';
import 'package:mobile_nebula/screens/siteConfig/CAListScreen.dart';
import 'package:mobile_nebula/screens/siteConfig/CertificateScreen.dart';
import 'package:mobile_nebula/screens/siteConfig/StaticHostsScreen.dart';
import 'package:mobile_nebula/services/utils.dart';

//TODO: Add a config test mechanism

class SiteConfigScreen extends StatefulWidget {
  const SiteConfigScreen({Key key, this.site, this.onSave}) : super(key: key);

  final Site site;

  // This is called after the target OS has saved the configuration
  final ValueChanged<Site> onSave;

  @override
  _SiteConfigScreenState createState() => _SiteConfigScreenState();
}

class _SiteConfigScreenState extends State<SiteConfigScreen> {
  bool changed = false;
  bool newSite = false;
  bool debug = false;
  Site site;

  final nameController = TextEditingController();

  @override
  void initState() {
    if (widget.site == null) {
      newSite = true;
      site = Site();
    } else {
      site = widget.site;
      nameController.text = site.name;
    }

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
        title: newSite ? 'New Site' : 'Edit Site',
        changed: changed,
        onSave: () async {
          site.name = nameController.text;
          try {
            await site.save();
          } catch (error) {
            return Utils.popError(context, 'Failed to save the site configuration', error.toString());
          }

          Navigator.pop(context);
          if (widget.onSave != null) {
            widget.onSave(site);
          }
        },
        child: Column(
          children: <Widget>[
            _main(),
            _keys(),
            _hosts(),
            _advanced(),
            kDebugMode ? _debugConfig() : Container(height: 0),
          ],
        ));
  }

  Widget _debugConfig() {
    var data = "";
    try {
      final encoder = new JsonEncoder.withIndent('  ');
      data = encoder.convert(site);
    } catch (err) {
      data = err.toString();
    }

    return ConfigSection(label: 'DEBUG', children: [ConfigItem(labelWidth: 0, content: SpecialSelectableText(data))]);
  }

  Widget _main() {
    return ConfigSection(children: <Widget>[
      ConfigItem(
          label: Text("Name"),
          content: PlatformTextFormField(
            placeholder: 'Required',
            controller: nameController,
          ))
    ]);
  }

  Widget _keys() {
    final certError = site.cert == null || !site.cert.validity.valid;
    var caError = site.ca.length == 0;
    if (!caError) {
      site.ca.forEach((ca) {
        if (!ca.validity.valid) {
          caError = true;
        }
      });
    }

    return ConfigSection(
      label: "IDENTITY",
      children: [
        ConfigPageItem(
          label: Text('Certificate'),
          content: Wrap(alignment: WrapAlignment.end, crossAxisAlignment: WrapCrossAlignment.center, children: <Widget>[
            certError
                ? Padding(
                    child: Icon(Icons.error, color: CupertinoColors.systemRed.resolveFrom(context), size: 20),
                    padding: EdgeInsets.only(right: 5))
                : Container(),
            certError ? Text('Needs attention') : Text(site.cert.cert.details.name)
          ]),
          onPressed: () {
            Utils.openPage(context, (context) {
              return CertificateScreen(
                  cert: site.cert,
                  onSave: (result) {
                    setState(() {
                      changed = true;
                      site.cert = result.cert;
                      site.key = result.key;
                    });
                  });
            });
          },
        ),
        ConfigPageItem(
            label: Text("CA"),
            content:
                Wrap(alignment: WrapAlignment.end, crossAxisAlignment: WrapCrossAlignment.center, children: <Widget>[
              caError
                  ? Padding(
                      child: Icon(Icons.error, color: CupertinoColors.systemRed.resolveFrom(context), size: 20),
                      padding: EdgeInsets.only(right: 5))
                  : Container(),
              caError ? Text('Needs attention') : Text(Utils.itemCountFormat(site.ca.length))
            ]),
            onPressed: () {
              Utils.openPage(context, (context) {
                return CAListScreen(
                    cas: site.ca,
                    onSave: (ca) {
                      setState(() {
                        changed = true;
                        site.ca = ca;
                      });
                    });
              });
            })
      ],
    );
  }

  Widget _hosts() {
    return ConfigSection(
      label: "Set up static hosts and lighthouses",
      children: <Widget>[
        ConfigPageItem(
          label: Text('Hosts'),
          content: Wrap(alignment: WrapAlignment.end, crossAxisAlignment: WrapCrossAlignment.center, children: <Widget>[
            site.staticHostmap.length == 0
                ? Padding(
                    child: Icon(Icons.error, color: CupertinoColors.systemRed.resolveFrom(context), size: 20),
                    padding: EdgeInsets.only(right: 5))
                : Container(),
            site.staticHostmap.length == 0
                ? Text('Needs attention')
                : Text(Utils.itemCountFormat(site.staticHostmap.length))
          ]),
          onPressed: () {
            Utils.openPage(context, (context) {
              return StaticHostsScreen(
                  hostmap: site.staticHostmap,
                  onSave: (map) {
                    setState(() {
                      changed = true;
                      site.staticHostmap = map;
                    });
                  });
            });
          },
        ),
      ],
    );
  }

  Widget _advanced() {
    return ConfigSection(
      children: <Widget>[
        ConfigPageItem(
            label: Text('Advanced'),
            onPressed: () {
              Utils.openPage(context, (context) {
                return AdvancedScreen(
                    site: site,
                    onSave: (settings) {
                      setState(() {
                        changed = true;
                        site.cipher = settings.cipher;
                        site.lhDuration = settings.lhDuration;
                        site.port = settings.port;
                        site.logVerbosity = settings.verbosity;
                        site.unsafeRoutes = settings.unsafeRoutes;
                        site.dnsResolvers = settings.dnsResolvers;
                        site.mtu = settings.mtu;
                      });
                    });
              });
            })
      ],
    );
  }
}
