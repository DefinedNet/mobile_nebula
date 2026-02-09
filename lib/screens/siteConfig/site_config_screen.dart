import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart' as fpw;
import 'package:intl/intl.dart';
import 'package:mobile_nebula/components/config/config_item.dart';
import 'package:mobile_nebula/components/config/config_page_item.dart';
import 'package:mobile_nebula/components/config/config_section.dart';
import 'package:mobile_nebula/components/form_page.dart';
import 'package:mobile_nebula/components/platform_text_form_field.dart';
import 'package:mobile_nebula/models/site.dart';
import 'package:mobile_nebula/screens/siteConfig/add_certificate_screen.dart';
import 'package:mobile_nebula/screens/siteConfig/advanced_screen.dart';
import 'package:mobile_nebula/screens/siteConfig/ca_list_screen.dart';
import 'package:mobile_nebula/screens/siteConfig/certificate_details_screen.dart';
import 'package:mobile_nebula/screens/siteConfig/static_hosts_screen.dart';
import 'package:mobile_nebula/services/utils.dart';

//TODO: Add a config test mechanism
//TODO: Enforce a name

class SiteConfigScreen extends StatefulWidget {
  const SiteConfigScreen({super.key, this.site, required this.onSave, required this.supportsQRScanning});

  final Site? site;

  // This is called after the target OS has saved the configuration
  final ValueChanged<Site> onSave;

  final bool supportsQRScanning;

  @override
  SiteConfigScreenState createState() => SiteConfigScreenState();
}

class SiteConfigScreenState extends State<SiteConfigScreen> {
  bool changed = false;
  bool newSite = false;
  bool debug = false;
  late Site site;
  String? pubKey;
  String? privKey;

  static const platform = MethodChannel('net.defined.mobileNebula/NebulaVpnService');
  final nameController = TextEditingController();

  @override
  void initState() {
    //NOTE: this is slightly wasteful since a keypair will be generated every time this page is opened
    _generateKeys();
    if (widget.site == null) {
      newSite = true;
      site = Site();
    } else {
      site = widget.site!;
      nameController.text = site.name;
    }

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (pubKey == null || privKey == null) {
      return Center(
        child: fpw.PlatformCircularProgressIndicator(
          cupertino: (_, _) {
            return fpw.CupertinoProgressIndicatorData(radius: 50);
          },
        ),
      );
    }

    return FormPage(
      title: newSite ? 'New Site' : 'Edit Site',
      changed: changed,
      onSave: () async {
        site.name = nameController.text;
        try {
          await site.save();
        } catch (error) {
          return Utils.popError('Failed to save the site configuration', error.toString());
        }

        if (context.mounted) {
          Navigator.pop(context);
        }
        widget.onSave(site);
      },
      child: Column(
        children: <Widget>[
          _main(),
          _keys(),
          _hosts(),
          _advanced(),
          _managed(),
          kDebugMode ? _debugConfig() : Container(height: 0),
        ],
      ),
    );
  }

  Widget _debugConfig() {
    var data = "";
    try {
      final encoder = JsonEncoder.withIndent('  ');
      data = encoder.convert(site);
    } catch (err) {
      data = err.toString();
    }

    return ConfigSection(
      label: 'DEBUG',
      children: [ConfigItem(labelWidth: 0, content: SelectableText(data))],
    );
  }

  Widget _main() {
    return ConfigSection(
      children: <Widget>[
        ConfigItem(
          label: Text("Name"),
          content: PlatformTextFormField(
            placeholder: 'Required',
            controller: nameController,
            validator: (name) {
              if (name == null || name == "") {
                return "A name is required";
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _managed() {
    final formatter = DateFormat.yMMMMd('en_US').add_jm();
    var lastUpdate = "Unknown";
    if (site.lastManagedUpdate != null) {
      lastUpdate = formatter.format(site.lastManagedUpdate!.toLocal());
    }

    return site.managed
        ? ConfigSection(
            label: "MANAGED CONFIG",
            children: <Widget>[
              ConfigItem(
                label: Text("Last Update"),
                content: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[Text(lastUpdate)],
                ),
              ),
            ],
          )
        : Container();
  }

  Widget _keys() {
    final certError = site.certInfo == null || site.certInfo!.validity == null || !site.certInfo!.validity!.valid;
    var caError = false;
    if (!site.managed) {
      caError = site.ca.isEmpty;
      if (!caError) {
        for (var ca in site.ca) {
          if (ca.validity == null || !ca.validity!.valid) {
            caError = true;
          }
        }
      }
    }

    return ConfigSection(
      label: "IDENTITY",
      children: [
        ConfigPageItem(
          label: Text('Certificate'),
          content: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              certError
                  ? Padding(
                      padding: EdgeInsets.only(right: 5),
                      child: Icon(Icons.error, color: CupertinoColors.systemRed.resolveFrom(context), size: 20),
                    )
                  : Container(),
              certError ? Text('Needs attention') : Text(site.certInfo?.cert.name ?? 'Unknown certificate'),
            ],
          ),
          onPressed: () {
            Utils.openPage(context, (context) {
              if (site.certInfo != null) {
                return CertificateDetailsScreen(
                  certInfo: site.certInfo!,
                  pubKey: pubKey,
                  privKey: privKey,
                  onReplace: site.managed
                      ? null
                      : (result) {
                          setState(() {
                            changed = true;
                            site.certInfo = result.certInfo;
                            site.key = result.key;
                          });
                        },
                  supportsQRScanning: widget.supportsQRScanning,
                );
              }

              return AddCertificateScreen(
                pubKey: pubKey!,
                privKey: privKey!,
                onSave: (result) {
                  setState(() {
                    changed = true;
                    site.certInfo = result.certInfo;
                    site.key = result.key;
                  });
                },
                supportsQRScanning: widget.supportsQRScanning,
              );
            });
          },
        ),
        ConfigPageItem(
          label: Text("CA"),
          content: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              caError
                  ? Padding(
                      padding: EdgeInsets.only(right: 5),
                      child: Icon(Icons.error, color: CupertinoColors.systemRed.resolveFrom(context), size: 20),
                    )
                  : Container(),
              caError ? Text('Needs attention') : Text(Utils.itemCountFormat(site.ca.length)),
            ],
          ),
          onPressed: () {
            Utils.openPage(context, (context) {
              return CAListScreen(
                cas: site.ca,
                onSave: site.managed
                    ? null
                    : (ca) {
                        setState(() {
                          changed = true;
                          site.ca = ca;
                        });
                      },
                supportsQRScanning: widget.supportsQRScanning,
              );
            });
          },
        ),
      ],
    );
  }

  Widget _hosts() {
    return ConfigSection(
      label: "LIGHTHOUSES / STATIC HOSTS",
      children: <Widget>[
        ConfigPageItem(
          label: Text('Hosts'),
          content: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              site.staticHostmap.isEmpty
                  ? Padding(
                      padding: EdgeInsets.only(right: 5),
                      child: Icon(Icons.error, color: CupertinoColors.systemRed.resolveFrom(context), size: 20),
                    )
                  : Container(),
              site.staticHostmap.isEmpty
                  ? Text('Needs attention')
                  : Text(Utils.itemCountFormat(site.staticHostmap.length)),
            ],
          ),
          onPressed: () {
            Utils.openPage(context, (context) {
              return StaticHostsScreen(
                hostmap: site.staticHostmap,
                onSave: site.managed
                    ? null
                    : (map) {
                        setState(() {
                          changed = true;
                          site.staticHostmap = map;
                        });
                      },
              );
            });
          },
        ),
      ],
    );
  }

  Widget _advanced() {
    return ConfigSection(
      label: "ADVANCED",
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
                },
              );
            });
          },
        ),
      ],
    );
  }

  Future<void> _generateKeys() async {
    try {
      var kp = await platform.invokeMethod("nebula.generateKeyPair");
      Map<String, dynamic> keyPair = jsonDecode(kp);

      setState(() {
        pubKey = keyPair['PublicKey'];
        privKey = keyPair['PrivateKey'];
      });
    } on PlatformException catch (err) {
      Utils.popError('Failed to generate key pair', err.details ?? err.message);
    }
  }
}
