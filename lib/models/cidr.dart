import 'dart:io';

import 'package:mobile_nebula/errors/parse_error.dart';
import 'package:mobile_nebula/validators/ip_validator.dart';

class CIDR {
  CIDR({this.ip = '', this.bits = 0});

  String ip;
  int bits;

  @override
  String toString() {
    return '$ip/$bits';
  }

  String toJson() {
    return toString();
  }

  factory CIDR.fromString(String val) {
    final parts = val.split('/');
    if (parts.length != 2) {
      throw ParseError('missing / separator');
    }

    var (valid, family) = ipValidator(parts[0]);
    if (!valid) {
      throw ParseError('ip prefix was not an ip address: ${parts[0]}');
    }

    var bits = int.tryParse(parts[1]);
    if (bits == null) {
      throw ParseError('prefix length was not an integer: ${parts[1]}');
    }

    if (bits < 0) {
      throw ParseError('invalid prefix length: $bits');
    }

    if (family == InternetAddressType.IPv4 && bits > 32) {
      throw ParseError('invalid prefix length: $bits');
    } else if (family == InternetAddressType.IPv6 && bits > 128) {
      throw ParseError('invalid prefix length: $bits');
    }

    return CIDR(ip: parts[0], bits: bits);
  }
}
