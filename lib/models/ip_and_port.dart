import 'package:mobile_nebula/validators/dns_validator.dart';

import '../errors/parse_error.dart';

class IPAndPort {
  String ip;
  int? port;

  IPAndPort(this.ip, this.port);

  @override
  String toString() => ip.contains(':') ? '[$ip]:$port' : '$ip:$port';

  String toJson() {
    return toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is IPAndPort && ip == other.ip && port == other.port;

  @override
  int get hashCode => Object.hash(ip, port);

  factory IPAndPort.fromString(String val) {
    // Handle IPv6 addresses in brackets [::1]:port or [2001:db8::1]:port
    if (val.startsWith('[')) {
      final closeBracket = val.indexOf(']');
      if (closeBracket == -1) {
        throw ParseError('missing ] in address');
      }

      if (closeBracket + 1 >= val.length || val[closeBracket + 1] != ':') {
        throw ParseError('missing port in address');
      }

      final addr = val.substring(1, closeBracket);
      final portStr = val.substring(closeBracket + 2);

      // Validate IPv6 address
      if (!_isValidIPv6(addr)) {
        throw ParseError('invalid IPv6 address: $addr');
      }

      final port = _parsePort(portStr);
      return IPAndPort(addr, port);
    }

    // Handle IPv4, DNS names, or malformed IPv6
    final lastColon = val.lastIndexOf(':');
    if (lastColon == -1) {
      throw ParseError('missing port in address');
    }

    final addr = val.substring(0, lastColon);
    final portStr = val.substring(lastColon + 1);

    // Check if it contains multiple colons (unbracketed IPv6)
    if (addr.contains(':')) {
      throw ParseError('IPv6 address must be enclosed in brackets');
    }

    // Validate address (IPv4 or DNS name)
    if (!_isValidAddress(addr)) {
      throw ParseError('invalid address: $addr');
    }

    final port = _parsePort(portStr);
    return IPAndPort(addr, port);
  }
}

bool _isValidIPv6(String addr) {
  try {
    Uri.parseIPv6Address(addr);
    return true;
  } catch (e) {
    return false;
  }
}

bool _isValidIPv4(String addr) {
  try {
    Uri.parseIPv4Address(addr);
    return true;
  } catch (e) {
    return false;
  }
}

bool _isValidAddress(String addr) {
  // Try IPv4 first
  if (_isValidIPv4(addr)) {
    return true;
  }

  // Try as DNS name
  return dnsValidator(addr);
}

int _parsePort(String s) {
  if (s.isEmpty) {
    throw ParseError('port is empty');
  }

  final port = int.tryParse(s);
  if (port == null) {
    throw ParseError('invalid port: $s');
  }

  if (port < 0 || port > 65535) {
    throw ParseError('port out of range: $port');
  }

  return port;
}
