import 'dart:io';

(bool, InternetAddressType) ipValidator(String? str) {
  if (str == null) {
    return (false, InternetAddressType.any);
  }

  final ia = InternetAddress.tryParse(str);
  if (ia == null) {
    return (false, InternetAddressType.any);
  }


  switch (ia.type) {
    case InternetAddressType.IPv4:
    case InternetAddressType.IPv6:
      return (true, ia.type);
  }

  return (false, InternetAddressType.any);
}
