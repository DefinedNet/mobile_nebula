import 'package:flutter/material.dart';

class ConfigTextItem extends StatelessWidget {
  const ConfigTextItem({
    super.key,
    this.placeholder,
    this.controller,
    this.style = const TextStyle(fontFamily: 'RobotoMono'),
  });

  final String? placeholder;
  final TextEditingController? controller;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      autocorrect: false,
      minLines: 3,
      maxLines: 10,
      decoration: InputDecoration(
        hintText: placeholder,
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      style: style,
      controller: controller,
    );
  }
}
