// Inspired by https://github.com/suragch/string_validator/blob/master/lib/src/validator.dart

bool dnsValidator(String? str, {bool requireTld = true, bool allowUnderscore = false}) {
  if (str == null) {
    return false;
  }

  List<String> parts = str.split('.');
  if (requireTld) {
    var tld = parts.removeLast();
    if (parts.isEmpty || !RegExp(r'^[a-z]{2,}$').hasMatch(tld)) {
      return false;
    }
  }

  String part;
  for (var i = 0; i < parts.length; i++) {
    part = parts[i];
    if (allowUnderscore) {
      if (part.indexOf('__') >= 0) {
        return false;
      }
    }

    if (!RegExp(r'^[a-z\\u00a1-\\uffff0-9-]+$').hasMatch(part)) {
      return false;
    }

    if (part[0] == '-' || part[part.length - 1] == '-' || part.indexOf('---') >= 0) {
      return false;
    }
  }

  return true;
}
