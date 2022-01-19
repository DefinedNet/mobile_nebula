import 'dart:convert';

import 'package:barcode_scan/barcode_scan.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:mobile_nebula/components/SimplePage.dart';
import 'package:mobile_nebula/components/config/ConfigButtonItem.dart';
import 'package:mobile_nebula/components/config/ConfigItem.dart';
import 'package:mobile_nebula/components/config/ConfigSection.dart';
import 'package:mobile_nebula/components/config/ConfigTextItem.dart';
import 'package:mobile_nebula/models/Certificate.dart';
import 'package:mobile_nebula/services/share.dart';
import 'package:mobile_nebula/services/utils.dart';

import 'CertificateDetailsScreen.dart';

class CertificateResult {
  CertificateInfo certInfo;
  String key;

  CertificateResult({this.certInfo, this.key});
}

class AddCertificateScreen extends StatefulWidget {
  const AddCertificateScreen({Key key, this.onSave, this.onReplace}) : super(key: key);

  // onSave will pop a new CertificateDetailsScreen
  final ValueChanged<CertificateResult> onSave;
  // onReplace will return the CertificateResult, assuming the previous screen is a CertificateDetailsScreen
  final ValueChanged<CertificateResult> onReplace;

  @override
  _AddCertificateScreenState createState() => _AddCertificateScreenState();
}

class _AddCertificateScreenState extends State<AddCertificateScreen> {
  String pubKey;
  String privKey;

  String inputType = 'paste';

  final pasteController = TextEditingController();
  static const platform = MethodChannel('net.defined.mobileNebula/NebulaVpnService');

  @override
  void initState() {
    _generateKeys();
    super.initState();
  }

  @override
  void dispose() {
    pasteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (pubKey == null) {
      return Center(
        child: PlatformCircularProgressIndicator(cupertino: (_, __) {
          return CupertinoProgressIndicatorData(radius: 500);
        }),
      );
    }

    List<Widget> items = [];
    items.addAll(_buildShare());
    items.addAll(_buildLoadCert());

    return SimplePage(title: 'Certificate', child: Column(children: items));
  }

  _generateKeys() async {
    try {
      var kp = await platform.invokeMethod("nebula.generateKeyPair");
      Map<String, dynamic> keyPair = jsonDecode(kp);

      setState(() {
        pubKey = keyPair['PublicKey'];
        privKey = keyPair['PrivateKey'];
      });
    } on PlatformException catch (err) {
      Utils.popError(context, 'Failed to generate key pair', err.details ?? err.message);
    }
  }

  List<Widget> _buildShare() {
    return [
      ConfigSection(
          label: 'Share your public key with a nebula CA so they can sign and return a certificate',
          children: [
            ConfigItem(
              labelWidth: 0,
              content: SelectableText(pubKey, style: TextStyle(fontFamily: 'RobotoMono', fontSize: 14)),
            ),
            ConfigButtonItem(
              content: Text('Share Public Key'),
              onPressed: () async {
                await Share.share(title: 'Please sign and return a certificate', text: pubKey, filename: 'device.pub');
              },
            ),
          ])
    ];
  }

  List<Widget> _buildLoadCert() {
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
            placeholder: 'Certificate PEM Contents',
            controller: pasteController,
          ),
          ConfigButtonItem(
              content: Center(child: Text('Load Certificate')),
              onPressed: () {
                _addCertEntry(pasteController.text);
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
              content: Center(child: Text('Choose a file')),
              onPressed: () async {
                try {
                  final content = await Utils.pickFile(context);
                  if (content == null) {
                    return;
                  }

                  _addCertEntry(content);
                } catch (err) {
                  return Utils.popError(context, 'Failed to load certificate file', err.toString());
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
                  _addCertEntry(result.rawContent);
                }
              }),
        ],
      )
    ];
  }

  _addCertEntry(String rawCert) async {
    // Allow for app store review testing cert to override the generated key
    if (rawCert.trim() == _testCert) {
      privKey = _testKey;
    }

    try {
      var rawCerts = await platform.invokeMethod("nebula.parseCerts", <String, String>{"certs": rawCert});

      List<dynamic> certs = jsonDecode(rawCerts);
      if (certs.length > 0) {
        var tryCertInfo = CertificateInfo.fromJson(certs.first);
        if (tryCertInfo.cert.details.isCa) {
          return Utils.popError(context, 'Error loading certificate content',
              'A certificate authority is not appropriate for a client certificate.');
        } else if (!tryCertInfo.validity.valid) {
          return Utils.popError(context, 'Certificate was invalid', tryCertInfo.validity.reason);
        }

        //TODO: test that the pubkey we generated equals the pub key in the cert

        // If we are replacing we just return the results now
        if (widget.onReplace != null) {
          Navigator.pop(context);
          widget.onReplace(CertificateResult(certInfo: tryCertInfo, key: privKey));
          return;
        }

        // We have a cert, pop the details screen where they can hit save
        Utils.openPage(context, (context) {
          return CertificateDetailsScreen(
              certInfo: tryCertInfo,
              onSave: () {
                Navigator.pop(context);
                widget.onSave(CertificateResult(certInfo: tryCertInfo, key: privKey));
              });
        });
      }
    } on PlatformException catch (err) {
      return Utils.popError(context, 'Error loading certificate content', err.details ?? err.message);
    }
  }
}

// This a cert that if presented will swap the key to assist the app review process
const _testCert = '''-----BEGIN NEBULA CERTIFICATE-----
CpMBChdBcHAgU3RvcmUgUmV2aWV3IERldmljZRIKgpSghQyA/v//DyIGcmV2aWV3
IhRiNzJjZThiZWM5MDYwYTA3MmNmMSjvk7f5BTCPnYf0BzogYHa3YoNcFJxKX8bU
jK4pg0aIYxDkwk8aM7w1c+CQXSpKICx06NYtozgKaA2R9NO311D8T86iTXxLmjI4
0wzAXCSmEkCi9ocqtyQhNp75eKphqVlZNl1RXBo4hdY9jBdc9+b9o0bU4zxFxIRT
uDneQqytYS+BUfgNnGX5wsMxOEst/kkC
-----END NEBULA CERTIFICATE-----''';

const _testKey = '''-----BEGIN NEBULA X25519 PRIVATE KEY-----
UlyDdFn/2mLFykeWjCEwWVRSDHtMF7nz3At3O77Faf4=
-----END NEBULA X25519 PRIVATE KEY-----''';
