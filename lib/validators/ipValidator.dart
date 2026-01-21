import 'dart:io';

(bool, InternetAddressType) ipValidator(String? str, bool enableIPV6) {
  if (str == null) {
    return (false, InternetAddressType.any);
  }

  final ia = InternetAddress.tryParse(str);
  if (ia == null) {
    return (false, InternetAddressType.any);
  }

  switch (ia.type) {
    case InternetAddressType.IPv6:
      {
        if (enableIPV6) {
          return (true, InternetAddressType.IPv6);
        }
      }
      break;

    case InternetAddressType.IPv4:
      {
        return (true, InternetAddressType.IPv4);
      }
  }

  return (false, InternetAddressType.any);
}
