import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_nebula/components/config/config_item.dart';
import 'package:mobile_nebula/components/config/config_page_item.dart';
import 'package:mobile_nebula/components/config/config_section.dart';
import 'package:mobile_nebula/components/form_page.dart';
import 'package:mobile_nebula/components/platform_text_form_field.dart';
import 'package:mobile_nebula/models/site.dart';
import 'package:mobile_nebula/models/unsafe_route.dart';
import 'package:mobile_nebula/screens/siteConfig/cipher_screen.dart';
import 'package:mobile_nebula/screens/siteConfig/dns_resolvers_screen.dart';
import 'package:mobile_nebula/screens/siteConfig/log_verbosity_screen.dart';
import 'package:mobile_nebula/screens/siteConfig/rendered_config_screen.dart';
import 'package:mobile_nebula/services/utils.dart';

import 'unsafe_routes_screen.dart';

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
  const AdvancedScreen({super.key, required this.site, required this.onSave});

  final Site site;
  final ValueChanged<Advanced> onSave;

  @override
  AdvancedScreenState createState() => AdvancedScreenState();
}

class AdvancedScreenState extends State<AdvancedScreen> {
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
      child: Column(
        children: [
          ConfigSection(
            children: [
              ConfigItem(
                label: Text("Lighthouse interval"),
                labelWidth: 200,
                //TODO: Auto select on focus?
                content: widget.site.managed
                    ? Text("${settings.lhDuration} seconds", textAlign: TextAlign.right)
                    : PlatformTextFormField(
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
                      ),
              ),
              ConfigItem(
                label: Text("Listen port"),
                labelWidth: 150,
                //TODO: Auto select on focus?
                content: widget.site.managed
                    ? Text(settings.port.toString(), textAlign: TextAlign.right)
                    : PlatformTextFormField(
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
                      ),
              ),
              ConfigItem(
                label: Text("MTU"),
                labelWidth: 150,
                content: widget.site.managed
                    ? Text(settings.mtu.toString(), textAlign: TextAlign.right)
                    : PlatformTextFormField(
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
                      ),
              ),
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
                      },
                    );
                  });
                },
              ),
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
                      },
                    );
                  });
                },
              ),
              ConfigPageItem(
                label: Text('Unsafe routes'),
                labelWidth: 150,
                content: Text(Utils.itemCountFormat(settings.unsafeRoutes.length), textAlign: TextAlign.end),
                onPressed: () {
                  Utils.openPage(context, (context) {
                    return UnsafeRoutesScreen(
                      unsafeRoutes: settings.unsafeRoutes,
                      onSave: widget.site.managed
                          ? null
                          : (routes) {
                              setState(() {
                                settings.unsafeRoutes = routes;
                                changed = true;
                              });
                            },
                    );
                  });
                },
              ),
              ConfigPageItem(
                label: Text('DNS resolvers'),
                labelWidth: 150,
                content: Text(Utils.itemCountFormat(settings.dnsResolvers.length), textAlign: TextAlign.end),
                onPressed: () {
                  Utils.openPage(context, (context) {
                    return DnsResolversScreen(
                      dnsResolvers: settings.dnsResolvers,
                      onSave: widget.site.managed
                          ? null
                          : (resolvers) {
                              setState(() {
                                settings.dnsResolvers = resolvers;
                                changed = true;
                              });
                            },
                    );
                  });
                },
              ),
            ],
          ),
          ConfigSection(
            children: <Widget>[
              ConfigPageItem(
                label: Text('View rendered config'),
                labelWidth: 300,
                onPressed: () async {
                  try {
                    var config = await widget.site.renderConfig();
                    if (!context.mounted) {
                      return;
                    }
                    Utils.openPage(context, (context) {
                      return RenderedConfigScreen(config: config, name: widget.site.name);
                    });
                  } catch (err) {
                    Utils.popError('Failed to render the site config', err.toString());
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
