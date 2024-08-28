import 'dart:io';

bool ipValidator(String? str, bool enableIPV6) {
  if (str == null) {
    return false;
  }

  final ia = InternetAddress.tryParse(str);
  if (ia == null) {
    return false;
  }

  switch (ia.type) {
    case InternetAddressType.IPv6:
      {
        if (enableIPV6) {
          return true;
        }
      }
      break;

    case InternetAddressType.IPv4:
      {
        return true;
      }
  }

  return false;
}
