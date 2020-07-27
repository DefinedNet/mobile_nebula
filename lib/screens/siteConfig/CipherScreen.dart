import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:mobile_nebula/components/FormPage.dart';
import 'package:mobile_nebula/components/config/ConfigCheckboxItem.dart';
import 'package:mobile_nebula/components/config/ConfigSection.dart';
import 'package:mobile_nebula/services/utils.dart';

class CipherScreen extends StatefulWidget {
  const CipherScreen({Key key, this.cipher, @required this.onSave}) : super(key: key);

  final String cipher;
  final ValueChanged<String> onSave;

  @override
  _CipherScreenState createState() => _CipherScreenState();
}

class _CipherScreenState extends State<CipherScreen> {
  String cipher;
  bool changed = false;

  @override
  void initState() {
    cipher = widget.cipher;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
        title: 'Cipher Selection',
        changed: changed,
        onSave: () {
          Navigator.pop(context);
          if (widget.onSave != null) {
            widget.onSave(cipher);
          }
        },
        child: Column(
          children: <Widget>[
            ConfigSection(children: [
              ConfigCheckboxItem(
                label: Text("aes"),
                labelWidth: 150,
                checked: cipher == "aes",
                onChanged: () {
                  setState(() {
                    changed = true;
                    cipher = "aes";
                  });
                },
              ),
              ConfigCheckboxItem(
                label: Text("chachapoly"),
                labelWidth: 150,
                checked: cipher == "chachapoly",
                onChanged: () {
                  setState(() {
                    changed = true;
                    cipher = "chachapoly";
                  });
                },
              )
            ])
          ],
        ));
  }
}
