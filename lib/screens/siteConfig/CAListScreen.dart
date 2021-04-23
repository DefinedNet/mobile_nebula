import 'dart:convert';

import 'package:barcode_scan/barcode_scan.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_nebula/components/FormPage.dart';
import 'package:mobile_nebula/components/config/ConfigButtonItem.dart';
import 'package:mobile_nebula/components/config/ConfigPageItem.dart';
import 'package:mobile_nebula/components/config/ConfigSection.dart';
import 'package:mobile_nebula/components/config/ConfigTextItem.dart';
import 'package:mobile_nebula/models/Certificate.dart';
import 'package:mobile_nebula/screens/siteConfig/CertificateDetailsScreen.dart';
import 'package:mobile_nebula/services/utils.dart';

//TODO: wire up the focus nodes, add a done/next/prev to the keyboard
//TODO: you left off at providing the signed cert back. You need to verify it has your public key in it. You likely want to present the cert details before they can save
//TODO: In addition you will want to think about re-generation while the site is still active (This means storing multiple keys in secure storage)

class CAListScreen extends StatefulWidget {
  const CAListScreen({Key key, this.cas, @required this.onSave}) : super(key: key);

  final List<CertificateInfo> cas;
  final ValueChanged<List<CertificateInfo>> onSave;

  @override
  _CAListScreenState createState() => _CAListScreenState();
}

class _CAListScreenState extends State<CAListScreen> {
  Map<String, CertificateInfo> cas = {};
  bool changed = false;
  var inputType = "paste";
  final pasteController = TextEditingController();
  static const platform = MethodChannel('net.defined.mobileNebula/NebulaVpnService');
  var error = "";

  @override
  void initState() {
    widget.cas.forEach((ca) {
      cas[ca.cert.fingerprint] = ca;
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> items = [];
    final caItems = _buildCAs();

    if (caItems.length > 0) {
      items.add(ConfigSection(children: caItems));
    }

    items.addAll(_addCA());
    return FormPage(
        title: 'Certificate Authorities',
        changed: changed,
        onSave: () {
          if (widget.onSave != null) {
            Navigator.pop(context);
            widget.onSave(cas.values.map((ca) {
              return ca;
            }).toList());
          }
        },
        child: Column(children: items));
  }

  List<Widget> _buildCAs() {
    List<Widget> items = [];
    cas.forEach((key, ca) {
      items.add(ConfigPageItem(
        content: Text(ca.cert.details.name),
        onPressed: () {
          Utils.openPage(context, (context) {
            return CertificateDetailsScreen(
                certificate: ca,
                onDelete: () {
                  setState(() {
                    changed = true;
                    cas.remove(key);
                  });
                });
          });
        },
      ));
    });

    return items;
  }

  _addCAEntry(String ca, ValueChanged<String> callback) async {
    String error;

    //TODO: show an error popup
    try {
      var rawCerts = await platform.invokeMethod("nebula.parseCerts", <String, String>{"certs": ca});
      var ignored = 0;

      List<dynamic> certs = jsonDecode(rawCerts);
      certs.forEach((rawCert) {
        final info = CertificateInfo.fromJson(rawCert);
        if (!info.cert.details.isCa) {
          ignored++;
          return;
        }
        cas[info.cert.fingerprint] = info;
      });

      if (ignored > 0) {
        error = 'One or more certificates were ignored because they were not certificate authorities.';
      }

      changed = true;
    } on PlatformException catch (err) {
      //TODO: fix this message
      error = err.details ?? err.message;
    }

    if (callback != null) {
      callback(error);
    }
  }

  List<Widget> _addCA() {
    List<Widget> items = [
      Padding(
          padding: EdgeInsets.fromLTRB(10, 25, 10, 0),
          child: CupertinoSlidingSegmentedControl(
            groupValue: inputType,
            onValueChanged: (v) {
              setState(() {
                inputType = v;
              });
            },
            children: {
              'paste': Text('Copy/Paste'),
              'file': Text('File'),
              'qr': Text('QR Code'),
            },
          ))
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
          ConfigTextItem(
            placeholder: 'CA PEM contents',
            controller: pasteController,
          ),
          ConfigButtonItem(
              content: Text('Load CA'),
              onPressed: () {
                _addCAEntry(pasteController.text, (err) {
                  print(err);
                  if (err != null) {
                    return Utils.popError(context, 'Failed to parse CA content', err);
                  }

                  pasteController.text = '';
                  setState(() {});
                });
              }),
        ],
      )
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
                  _addCAEntry(content, (err) {
                    if (err != null) {
                      Utils.popError(context, 'Error loading CA file', err);
                    } else {
                      setState(() {});
                    }
                  });

                } catch (err) {
                  return Utils.popError(context, 'Failed to load CA file', err.toString());
                }
              })
        ],
      )
    ];
  }

  List<Widget> _addQr() {
    return [
      ConfigSection(
        children: [
          ConfigButtonItem(
              content: Text('Scan a QR code'),
              onPressed: () async {
                var options = ScanOptions(
                  restrictFormat: [BarcodeFormat.qr],
                );

                var result = await BarcodeScanner.scan(options: options);
                if (result.rawContent != "") {
                  _addCAEntry(result.rawContent, (err) {
                    if (err != null) {
                      Utils.popError(context, 'Error loading CA content', err);
                    } else {
                      setState(() {});
                    }
                  });
                }
              })
        ],
      )
    ];
  }
}
