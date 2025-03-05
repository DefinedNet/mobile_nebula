import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_nebula/components/FormPage.dart';
import 'package:mobile_nebula/components/config/ConfigCheckboxItem.dart';
import 'package:mobile_nebula/components/config/ConfigSection.dart';

class CipherScreen extends StatefulWidget {
  const CipherScreen({super.key, required this.cipher, required this.onSave});

  final String cipher;
  final ValueChanged<String> onSave;

  @override
  _CipherScreenState createState() => _CipherScreenState();
}

class _CipherScreenState extends State<CipherScreen> {
  late String cipher;
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
        widget.onSave(cipher);
      },
      child: Column(
        children: <Widget>[
          ConfigSection(
            children: [
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
              ),
            ],
          ),
        ],
      ),
    );
  }
}
