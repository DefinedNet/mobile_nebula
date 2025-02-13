import 'package:flutter/cupertino.dart';

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
    return CupertinoTextFormFieldRow(
      autocorrect: false,
      minLines: 3,
      maxLines: 10,
      placeholder: placeholder,
      style: style,
      controller: controller,
    );
  }
}
