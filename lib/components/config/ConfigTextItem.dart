import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile_nebula/components/SpecialTextField.dart';

class ConfigTextItem extends StatelessWidget {
  const ConfigTextItem({Key? key, this.placeholder, this.controller, this.style = const TextStyle(fontFamily: 'RobotoMono')}) : super(key: key);

  final String? placeholder;
  final TextEditingController? controller;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: Platform.isAndroid ? EdgeInsets.all(5) : EdgeInsets.zero,
        child: SpecialTextField(
            autocorrect: false,
            minLines: 3,
            maxLines: 10,
            placeholder: placeholder,
            style: style,
            controller: controller));
  }
}
