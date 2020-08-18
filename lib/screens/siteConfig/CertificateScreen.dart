import 'dart:convert';

import 'package:barcode_scan/barcode_scan.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_nebula/components/FormPage.dart';
import 'package:mobile_nebula/components/config/ConfigButtonItem.dart';
import 'package:mobile_nebula/components/config/ConfigItem.dart';
import 'package:mobile_nebula/components/config/ConfigPageItem.dart';
import 'package:mobile_nebula/components/config/ConfigSection.dart';
import 'package:mobile_nebula/components/config/ConfigTextItem.dart';
import 'package:mobile_nebula/models/Certificate.dart';
import 'package:mobile_nebula/screens/siteConfig/CertificateDetailsScreen.dart';
import 'package:mobile_nebula/services/share.dart';
import 'package:mobile_nebula/services/utils.dart';

class CertificateResult {
  CertificateInfo cert;
  String key;

  CertificateResult({this.cert, this.key});
}

class CertificateScreen extends StatefulWidget {
  const CertificateScreen({Key key, this.cert, this.onSave}) : super(key: key);

  final CertificateInfo cert;
  final ValueChanged<CertificateResult> onSave;

  @override
  _CertificateScreenState createState() => _CertificateScreenState();
}

class _CertificateScreenState extends State<CertificateScreen> {
  String pubKey;
  String privKey;
  bool changed = false;

  CertificateInfo cert;

  String inputType = 'paste';
  bool shared = false;

  final pasteController = TextEditingController();
  static const platform = MethodChannel('net.defined.mobileNebula/NebulaVpnService');

  @override
  void initState() {
    cert = widget.cert;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> items = [];
    bool hideSave = true;

    if (cert == null) {
      if (pubKey == null) {
        items = _buildGenerate();
      } else {
        items.addAll(_buildShare());
        items.addAll(_buildLoadCert());
      }
    } else {
      items.addAll(_buildCertList());
      hideSave = false;
    }

    return FormPage(
        title: 'Certificate',
        changed: changed,
        hideSave: hideSave,
        onSave: () {
          Navigator.pop(context);
          if (widget.onSave != null) {
            widget.onSave(CertificateResult(cert: cert, key: privKey));
          }
        },
        child: Column(children: items));
  }

  _buildCertList() {
    //TODO: generate a full list
    return [
      ConfigSection(
        children: [
          ConfigPageItem(
            content: Text(cert.cert.details.name),
            onPressed: () {
              Utils.openPage(context, (context) {
                //TODO: wire on delete
                return CertificateDetailsScreen(certificate: cert);
              });
            },
          )
        ],
      )
    ];
  }

  List<Widget> _buildGenerate() {
    return [
      ConfigSection(label: 'Please generate a new public and private key', children: [
        ConfigButtonItem(
          content: Text('Generate Keys'),
          onPressed: () => _generateKeys(),
        )
      ])
    ];
  }

  _generateKeys() async {
    try {
      var kp = await platform.invokeMethod("nebula.generateKeyPair");
      Map<String, dynamic> keyPair = jsonDecode(kp);

      setState(() {
        changed = true;
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
                setState(() {
                  shared = true;
                });
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
                _addCertEntry(pasteController.text, (err) {
                  if (err != null) {
                    return Utils.popError(context, 'Failed to parse certificate content', err);
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
              content: Center(child: Text('Choose a file')),
              onPressed: () async {
                var file;
                try {
                  await FilePicker.clearTemporaryFiles();
                  file = await FilePicker.getFile();

                  if (file == null) {
                    print('GOT A NULL');
                    return;
                  }
                } catch (err) {
                  print('HEY $err');
                }

                var content = "";
                try {
                  content = file.readAsStringSync();
                } catch (err) {
                  print('CAUGH IN READ ${file}');
                  return Utils.popError(context, 'Failed to load CA file', err.toString());
                }

                _addCertEntry(content, (err) {
                  if (err != null) {
                    Utils.popError(context, 'Error loading certificate file', err);
                  } else {
                    setState(() {});
                  }
                });
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
                  _addCertEntry(result.rawContent, (err) {
                    if (err != null) {
                      Utils.popError(context, 'Error loading certificate content', err);
                    } else {
                      setState(() {});
                    }
                  });
                }
              }),
        ],
      )
    ];
  }

  _addCertEntry(String rawCert, ValueChanged<String> callback) async {
    String error;

    // Allow for app store review testing cert to override the generated key
    if (rawCert.trim() == _testCert) {
      privKey = _testKey;
    }

    try {
      var rawCerts = await platform.invokeMethod("nebula.parseCerts", <String, String>{"certs": rawCert});
      List<dynamic> certs = jsonDecode(rawCerts);
      if (certs.length > 0) {
        var tryCert = CertificateInfo.fromJson(certs.first);
        if (tryCert.cert.details.isCa) {
          return callback('A certificate authority is not appropriate for a client certificate.');
        }
        //TODO: test that the pubkey matches the privkey
        cert = tryCert;
      }
    } on PlatformException catch (err) {
      error = err.details ?? err.message;
    }

    if (callback != null) {
      callback(error);
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