// Inspired by https://github.com/suragch/string_validator/blob/master/lib/src/validator.dart

final _ipv4 = RegExp(r'^(\d?\d?\d)\.(\d?\d?\d)\.(\d?\d?\d)\.(\d?\d?\d)$');

bool ipValidator(str) {
  if (str == null) {
    return false;
  }

  if (!_ipv4.hasMatch(str)) {
    return false;
  }

  var parts = str.split('.');
  parts.sort((a, b) => int.parse(a) - int.parse(b));
  return int.parse(parts[3]) <= 255;
}
