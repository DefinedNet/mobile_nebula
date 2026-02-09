import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:mobile_nebula/components/config/config_button_item.dart';
import 'package:mobile_nebula/components/config/config_page_item.dart';
import 'package:mobile_nebula/components/config/config_section.dart';
import 'package:mobile_nebula/components/config/config_text_item.dart';
import 'package:mobile_nebula/components/form_page.dart';
import 'package:mobile_nebula/models/certificate.dart';
import 'package:mobile_nebula/screens/siteConfig/certificate_details_screen.dart';
import 'package:mobile_nebula/screens/siteConfig/scan_qr_screen.dart';
import 'package:mobile_nebula/services/utils.dart';

//TODO: wire up the focus nodes, add a done/next/prev to the keyboard
//TODO: you left off at providing the signed cert back. You need to verify it has your public key in it. You likely want to present the cert details before they can save
//TODO: In addition you will want to think about re-generation while the site is still active (This means storing multiple keys in secure storage)

class CAListScreen extends StatefulWidget {
  const CAListScreen({super.key, required this.cas, this.onSave, required this.supportsQRScanning});

  final List<CertificateInfo> cas;
  final ValueChanged<List<CertificateInfo>>? onSave;

  final bool supportsQRScanning;

  @override
  CAListScreenState createState() => CAListScreenState();
}

class CAListScreenState extends State<CAListScreen> {
  Map<String, CertificateInfo> cas = {};
  bool changed = false;
  var inputType = "paste";
  final pasteController = TextEditingController();
  static const platform = MethodChannel('net.defined.mobileNebula/NebulaVpnService');
  var error = "";

  @override
  void initState() {
    for (var ca in widget.cas) {
      cas[ca.cert.fingerprint] = ca;
    }

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> items = [];
    final caItems = _buildCAs();

    if (caItems.isNotEmpty) {
      items.add(ConfigSection(children: caItems));
    }

    if (widget.onSave != null) {
      items.addAll(_addCA());
    }

    return FormPage(
      title: 'Certificate Authorities',
      changed: changed,
      onSave: () {
        if (widget.onSave != null) {
          Navigator.pop(context);
          widget.onSave!(
            cas.values.map((ca) {
              return ca;
            }).toList(),
          );
        }
      },
      child: Column(children: items),
    );
  }

  List<Widget> _buildCAs() {
    List<Widget> items = [];
    cas.forEach((key, ca) {
      items.add(
        ConfigPageItem(
          content: Text(ca.cert.name),
          onPressed: () {
            Utils.openPage(context, (context) {
              return CertificateDetailsScreen(
                certInfo: ca,
                onDelete:
                    widget.onSave == null
                        ? null
                        : () {
                          setState(() {
                            changed = true;
                            cas.remove(key);
                          });
                        },
                supportsQRScanning: widget.supportsQRScanning,
              );
            });
          },
        ),
      );
    });

    return items;
  }

  _addCAEntry(String ca, ValueChanged<String?> callback) async {
    String? error;

    //TODO: show an error popup
    try {
      var rawCerts = await platform.invokeMethod("nebula.parseCerts", <String, String>{"certs": ca});
      var ignored = 0;

      List<dynamic> certs = jsonDecode(rawCerts);
      for (var rawCert in certs) {
        final info = CertificateInfo.fromJson(rawCert);
        if (!info.cert.isCa) {
          ignored++;
          continue;
        }
        cas[info.cert.fingerprint] = info;
      }

      if (ignored > 0) {
        error = 'One or more certificates were ignored because they were not certificate authorities.';
      }

      changed = true;
    } on PlatformException catch (err) {
      //TODO: fix this message
      error = err.details ?? err.message;
    }

    callback(error);
  }

  List<Widget> _addCA() {
    Map<String, Widget> children = {'paste': Text('Copy/Paste'), 'file': Text('File')};

    // not all devices have a camera for QR codes
    if (widget.supportsQRScanning) {
      children['qr'] = Text('QR Code');
    }

    List<Widget> items = [
      Padding(
        padding: EdgeInsets.fromLTRB(10, 25, 10, 0),
        child: CupertinoSlidingSegmentedControl(
          groupValue: inputType,
          onValueChanged: (v) {
            if (v != null) {
              setState(() {
                inputType = v;
              });
            }
          },
          children: children,
        ),
      ),
    ];

    if (inputType == 'paste') {
      items.addAll(_addPaste());
    } else if (inputType == 'file') {
      items.addAll(_addFile());
    } else {
      items.addAll(_addQr());
    }

    return items;
  }

  List<Widget> _addPaste() {
    return [
      ConfigSection(
        children: [
          ConfigTextItem(placeholder: 'CA PEM contents', controller: pasteController),
          ConfigButtonItem(
            content: Text('Load CA'),
            onPressed: () {
              _addCAEntry(pasteController.text, (err) {
                print(err);
                if (err != null) {
                  return Utils.popError('Failed to parse CA content', err);
                }

                pasteController.text = '';
                setState(() {});
              });
            },
          ),
        ],
      ),
    ];
  }

  List<Widget> _addFile() {
    return [
      ConfigSection(
        children: [
          ConfigButtonItem(
            content: Text('Choose a file'),
            onPressed: () async {
              try {
                final content = await Utils.pickFile(context);
                if (content == null) {
                  return;
                }

                _addCAEntry(content, (err) {
                  if (err != null) {
                    Utils.popError('Error loading CA file', err);
                  } else {
                    setState(() {});
                  }
                });
              } catch (err) {
                return Utils.popError('Failed to load CA file', err.toString());
              }
            },
          ),
        ],
      ),
    ];
  }

  List<Widget> _addQr() {
    return [
      ConfigSection(
        children: [
          ConfigButtonItem(
            content: Text('Scan a QR code'),
            onPressed: () async {
              var result = await Navigator.push(
                context,
                platformPageRoute(context: context, builder: (context) => ScanQRScreen()),
              );
              if (result != null) {
                _addCAEntry(result, (err) {
                  if (err != null) {
                    Utils.popError('Error loading CA content', err);
                  } else {
                    setState(() {});
                  }
                });
              }
            },
          ),
        ],
      ),
    ];
  }
}
