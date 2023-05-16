import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_nebula/components/FormPage.dart';
import 'package:mobile_nebula/components/PlatformTextFormField.dart';
import 'package:mobile_nebula/components/config/ConfigPageItem.dart';
import 'package:mobile_nebula/components/config/ConfigItem.dart';
import 'package:mobile_nebula/components/config/ConfigSection.dart';
import 'package:mobile_nebula/models/Site.dart';
import 'package:mobile_nebula/models/UnsafeRoute.dart';
import 'package:mobile_nebula/screens/siteConfig/CipherScreen.dart';
import 'package:mobile_nebula/screens/siteConfig/DNSResolversScreen.dart';
import 'package:mobile_nebula/screens/siteConfig/LogVerbosityScreen.dart';
import 'package:mobile_nebula/screens/siteConfig/RenderedConfigScreen.dart';
import 'package:mobile_nebula/services/utils.dart';

import 'UnsafeRoutesScreen.dart';

//TODO: form validation (seconds and port)
//TODO: wire up the focus nodes, add a done/next/prev to the keyboard
//TODO: fingerprint blacklist
//TODO: show site id here

class Advanced {
  int lhDuration;
  int port;
  String cipher;
  String verbosity;
  List<UnsafeRoute> unsafeRoutes;
  int mtu;
  List<String> dnsResolvers;

  Advanced({
    required this.lhDuration,
    required this.port,
    required this.cipher,
    required this.verbosity,
    required this.unsafeRoutes,
    required this.mtu,
    required this.dnsResolvers,
  });
}

class AdvancedScreen extends StatefulWidget {
  const AdvancedScreen({
    Key? key,
    required this.site,
    required this.onSave,
  }) : super(key: key);

  final Site site;
  final ValueChanged<Advanced> onSave;

  @override
  _AdvancedScreenState createState() => _AdvancedScreenState();
}

class _AdvancedScreenState extends State<AdvancedScreen> {
  late Advanced settings;
  var changed = false;

  @override
  void initState() {
    settings = Advanced(
      lhDuration: widget.site.lhDuration,
      port: widget.site.port,
      cipher: widget.site.cipher,
      verbosity: widget.site.logVerbosity,
      unsafeRoutes: widget.site.unsafeRoutes,
      mtu: widget.site.mtu,
      dnsResolvers: widget.site.dnsResolvers,
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
        title: 'Advanced Settings',
        changed: changed,
        onSave: () {
          Navigator.pop(context);
          widget.onSave(settings);
        },
        child: Column(children: [
          ConfigSection(
            children: [
              ConfigItem(
                  label: Text("Lighthouse interval"),
                  labelWidth: 200,
                  //TODO: Auto select on focus?
                  content: widget.site.managed ?
                    Text(settings.lhDuration.toString() + " seconds", textAlign: TextAlign.right) :
                    PlatformTextFormField(
                      initialValue: settings.lhDuration.toString(),
                      keyboardType: TextInputType.number,
                      suffix: Text("seconds"),
                      textAlign: TextAlign.right,
                      maxLength: 5,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onSaved: (val) {
                        setState(() {
                          if (val != null) {
                            settings.lhDuration = int.parse(val);
                          }
                        });
                      },
                    )),
              ConfigItem(
                  label: Text("Listen port"),
                  labelWidth: 150,
                  //TODO: Auto select on focus?
                  content: widget.site.managed ?
                    Text(settings.port.toString(), textAlign: TextAlign.right) :
                    PlatformTextFormField(
                      initialValue: settings.port.toString(),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      maxLength: 5,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onSaved: (val) {
                        setState(() {
                          if (val != null) {
                            settings.port = int.parse(val);
                          }
                        });
                      },
                    )),
              ConfigItem(
                  label: Text("MTU"),
                  labelWidth: 150,
                  content: widget.site.managed ?
                    Text(settings.mtu.toString(), textAlign: TextAlign.right) :
                    PlatformTextFormField(
                      initialValue: settings.mtu.toString(),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      maxLength: 5,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onSaved: (val) {
                        setState(() {
                          if (val != null) {
                            settings.mtu = int.parse(val);
                          }
                        });
                      },
                    )),
              ConfigPageItem(
                  disabled: widget.site.managed,
                  label: Text('Cipher'),
                  labelWidth: 150,
                  content: Text(settings.cipher, textAlign: TextAlign.end),
                  onPressed: () {
                    Utils.openPage(context, (context) {
                      return CipherScreen(
                          cipher: settings.cipher,
                          onSave: (cipher) {
                            setState(() {
                              settings.cipher = cipher;
                              changed = true;
                            });
                          });
                    });
                  }),
              ConfigPageItem(
                  disabled: widget.site.managed,
                  label: Text('Log verbosity'),
                  labelWidth: 150,
                  content: Text(settings.verbosity, textAlign: TextAlign.end),
                  onPressed: () {
                    Utils.openPage(context, (context) {
                      return LogVerbosityScreen(
                          verbosity: settings.verbosity,
                          onSave: (verbosity) {
                            setState(() {
                              settings.verbosity = verbosity;
                              changed = true;
                            });
                          });
                    });
                  }),
              ConfigPageItem(
                label: Text('Unsafe routes'),
                labelWidth: 150,
                content: Text(Utils.itemCountFormat(settings.unsafeRoutes.length), textAlign: TextAlign.end),
                onPressed: () {
                  Utils.openPage(context, (context) {
                    return UnsafeRoutesScreen(
                        unsafeRoutes: settings.unsafeRoutes,
                        onSave: widget.site.managed ? null : (routes) {
                          setState(() {
                            settings.unsafeRoutes = routes;
                            changed = true;
                          });
                        });
                    });
                  },
              ),
              ConfigPageItem(
                label: Text('DNS Resolvers'),
                labelWidth: 150,
                content: Text(
                    Utils.itemCountFormat(settings.dnsResolvers.length),
                    textAlign: TextAlign.end),
                onPressed: () {
                  Utils.openPage(context, (context) {
                    return DNSResolversScreen(
                        dnsResolvers: settings.dnsResolvers,
                        onSave: (dnsResolvers) {
                          setState(() {
                            settings.dnsResolvers = dnsResolvers;
                            changed = true;
                          });
                        });
                  });
                },
              )
            ],
          ),
          ConfigSection(
            children: <Widget>[
              ConfigPageItem(
                content: Text('View rendered config'),
                onPressed: () async {
                  try {
                    var config = await widget.site.renderConfig();
                    Utils.openPage(context, (context) {
                      return RenderedConfigScreen(config: config, name: widget.site.name);
                    });
                  } catch (err) {
                    Utils.popError(context, 'Failed to render the site config', err.toString());
                  }
                },
              )
            ],
          )
        ]));
  }
}
